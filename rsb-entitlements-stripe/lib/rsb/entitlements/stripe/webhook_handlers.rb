module RSB
  module Entitlements
    module Stripe
      module WebhookHandlers
        LOG_TAG = RSB::Entitlements::Stripe::LOG_TAG

        HANDLERS = {
          "checkout.session.completed" => :handle_checkout_session_completed,
          "invoice.paid" => :handle_invoice_paid,
          "invoice.payment_failed" => :handle_invoice_payment_failed,
          "customer.subscription.updated" => :handle_subscription_updated,
          "customer.subscription.deleted" => :handle_subscription_deleted,
          "charge.refunded" => :handle_charge_refunded
        }.freeze

        def self.handle(event)
          handler = HANDLERS[event.type]
          if handler
            send(handler, event)
          else
            Rails.logger.debug("#{LOG_TAG} Ignoring unhandled event type: #{event.type}")
          end
        end

        # Handles checkout.session.completed — grants entitlement for the payment.
        # For subscription mode, updates provider_ref to subscription ID.
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_checkout_session_completed(event)
          session = event.data.object
          checkout_session_id = session.id

          # Find PaymentRequest by provider_ref (session ID) or metadata
          payment_request = find_payment_request_by_session(session)
          unless payment_request
            Rails.logger.warn("#{LOG_TAG} No PaymentRequest found for checkout session #{checkout_session_id}")
            return
          end

          # Idempotent: skip if already approved
          unless payment_request.actionable?
            Rails.logger.info("#{LOG_TAG} PaymentRequest ##{payment_request.id} already processed, skipping")
            return
          end

          # Update provider_data with Stripe details
          data = payment_request.provider_data || {}
          data["customer_id"] = session.customer.to_s if session.respond_to?(:customer) && session.customer
          mode = data["mode"] || session.mode

          complete_params = {}

          if mode == "subscription" && session.respond_to?(:subscription) && session.subscription
            subscription_id = session.subscription.to_s
            data["subscription_id"] = subscription_id
            complete_params[:subscription_id] = subscription_id
            # Update provider_ref to subscription ID for future lifecycle events
            payment_request.update!(provider_ref: subscription_id, provider_data: data)
          elsif session.respond_to?(:payment_intent) && session.payment_intent
            data["payment_intent_id"] = session.payment_intent.to_s
            payment_request.update!(provider_data: data)
          else
            payment_request.update!(provider_data: data)
          end

          # Grant entitlement
          provider = RSB::Entitlements::Stripe::PaymentProvider.new(payment_request)
          provider.complete!(complete_params)

          # Store Stripe Customer ID on requestable for future checkouts
          store_customer_id(payment_request.requestable, data["customer_id"])

          Rails.logger.info("#{LOG_TAG} Granted entitlement for PaymentRequest ##{payment_request.id}")
        end

        # Handles invoice.paid — extends subscription entitlement to next billing period.
        # Also re-activates entitlements that were revoked due to past_due.
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_invoice_paid(event)
          invoice = event.data.object
          subscription_id = invoice.respond_to?(:subscription) ? invoice.subscription&.to_s : nil

          unless subscription_id.present?
            Rails.logger.debug("#{LOG_TAG} invoice.paid without subscription_id, skipping")
            return
          end

          entitlement = find_entitlement_by_subscription(subscription_id)
          unless entitlement
            Rails.logger.warn("#{LOG_TAG} No Entitlement found for subscription #{subscription_id}")
            return
          end

          # Extend entitlement to next billing period
          period_end = if invoice.respond_to?(:lines) && invoice.lines.respond_to?(:data) && invoice.lines.data.any?
            line = invoice.lines.data.first
            if line.respond_to?(:period) && line.period.respond_to?(:end)
              Time.at(line.period.end)
            end
          end

          # Default: extend by 1 month if period_end is not available
          period_end ||= 1.month.from_now

          updates = { expires_at: period_end }
          # Re-activate if previously revoked/expired
          updates[:status] = "active" unless entitlement.status == "active"

          entitlement.update!(updates)

          # Update invoice_id on the payment request
          payment_request = find_payment_request_by_subscription(subscription_id)
          if payment_request
            data = payment_request.provider_data || {}
            data["invoice_id"] = invoice.id.to_s
            payment_request.update!(provider_data: data)
          end

          fire_callback(:after_entitlement_changed, entitlement)
          Rails.logger.info("#{LOG_TAG} Extended entitlement for subscription #{subscription_id}")
        end

        # Handles invoice.payment_failed — records failure info without revoking.
        # Stripe handles retries via Smart Retries. Fires callback for host app notification.
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_invoice_payment_failed(event)
          invoice = event.data.object
          subscription_id = invoice.respond_to?(:subscription) ? invoice.subscription&.to_s : nil

          return unless subscription_id.present?

          payment_request = find_payment_request_by_subscription(subscription_id)
          unless payment_request
            Rails.logger.warn("#{LOG_TAG} No PaymentRequest found for subscription #{subscription_id}")
            return
          end

          # Store failure info
          data = payment_request.provider_data || {}
          data["failure_code"] = invoice.respond_to?(:last_finalization_error) ?
            invoice.last_finalization_error&.code : nil
          data["failure_message"] = invoice.respond_to?(:last_finalization_error) ?
            invoice.last_finalization_error&.message : "Payment failed"
          data["invoice_id"] = invoice.id.to_s

          payment_request.update!(provider_data: data)
          fire_callback(:after_payment_request_changed, payment_request)
          Rails.logger.info("#{LOG_TAG} Recorded payment failure for subscription #{subscription_id}")
        end

        # Handles customer.subscription.updated — syncs subscription status with entitlement.
        # Stripe subscription statuses: active, past_due, unpaid, canceled, incomplete, incomplete_expired, paused, trialing.
        # RSB entitlement statuses: pending, active, revoked, expired.
        # Mapping: active/trialing → active, past_due → active (Smart Retries handle recovery),
        #          canceled/unpaid/incomplete_expired → revoked.
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_subscription_updated(event)
          subscription = event.data.object
          subscription_id = subscription.id.to_s
          status = subscription.respond_to?(:status) ? subscription.status.to_s : nil

          entitlement = find_entitlement_by_subscription(subscription_id)
          unless entitlement
            Rails.logger.warn("#{LOG_TAG} No Entitlement found for subscription #{subscription_id}")
            return
          end

          # Map Stripe subscription status to RSB entitlement status
          case status
          when "active", "trialing"
            # Activate if not already active
            unless entitlement.status == "active"
              entitlement.update!(status: "active", activated_at: Time.current)
              fire_callback(:after_entitlement_changed, entitlement)
              Rails.logger.info("#{LOG_TAG} Activated entitlement for subscription #{subscription_id}")
            end
          when "past_due"
            # Keep active — Stripe Smart Retries will handle recovery or eventual cancellation
            Rails.logger.info("#{LOG_TAG} Subscription #{subscription_id} is past_due, keeping entitlement active")
          when "canceled", "unpaid", "incomplete_expired"
            # Revoke entitlement — map to :non_renewal (valid Entitlement::REVOKE_REASONS)
            revoke_entitlement(entitlement, reason: "non_renewal")
            Rails.logger.info("#{LOG_TAG} Revoked entitlement for subscription #{subscription_id} (status: #{status})")
          when "incomplete", "paused"
            # No action — incomplete subscriptions haven't been granted yet, paused are suspended
            Rails.logger.debug("#{LOG_TAG} Subscription #{subscription_id} status #{status}, no action")
          else
            Rails.logger.warn("#{LOG_TAG} Unknown subscription status: #{status} for #{subscription_id}")
          end
        end

        # Handles customer.subscription.deleted — revokes entitlement and expires payment request.
        # This event fires when a subscription is permanently deleted (e.g., via dashboard or after grace period).
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_subscription_deleted(event)
          subscription = event.data.object
          subscription_id = subscription.id.to_s

          entitlement = find_entitlement_by_subscription(subscription_id)
          unless entitlement
            Rails.logger.warn("#{LOG_TAG} No Entitlement found for subscription #{subscription_id}")
            return
          end

          # Revoke entitlement — map to :non_renewal (valid Entitlement::REVOKE_REASONS)
          revoke_entitlement(entitlement, reason: "non_renewal")

          # Mark payment request as expired
          payment_request = find_payment_request_by_subscription(subscription_id)
          if payment_request && payment_request.status != "expired"
            payment_request.update!(status: "expired", expires_at: Time.current)
            fire_callback(:after_payment_request_changed, payment_request)
          end

          Rails.logger.info("#{LOG_TAG} Revoked entitlement and expired payment request for deleted subscription #{subscription_id}")
        end

        # Handles charge.refunded — auto-revokes entitlement with reason :refund.
        # Finds PaymentRequest by payment_intent_id from provider_data, then revokes associated entitlement.
        #
        # @param event [Stripe::Event]
        # @return [void]
        def self.handle_charge_refunded(event)
          charge = event.data.object
          payment_intent_id = charge.respond_to?(:payment_intent) ? charge.payment_intent&.to_s : nil

          unless payment_intent_id.present?
            Rails.logger.debug("#{LOG_TAG} charge.refunded without payment_intent, skipping")
            return
          end

          # Find PaymentRequest by payment_intent_id in provider_data
          payment_request = find_payment_request_by_payment_intent(payment_intent_id)

          unless payment_request
            Rails.logger.warn("#{LOG_TAG} No PaymentRequest found for payment_intent #{payment_intent_id}")
            return
          end

          entitlement = payment_request.entitlement
          unless entitlement
            Rails.logger.warn("#{LOG_TAG} No Entitlement found for PaymentRequest ##{payment_request.id}")
            return
          end

          # Revoke entitlement with refund reason
          revoke_entitlement(entitlement, reason: "refund")

          Rails.logger.info("#{LOG_TAG} Revoked entitlement for refunded charge (payment_intent: #{payment_intent_id})")
        end

        # Find PaymentRequest by checkout session ID or metadata.
        #
        # @param session [Stripe::Checkout::Session]
        # @return [RSB::Entitlements::PaymentRequest, nil]
        def self.find_payment_request_by_session(session)
          pr = RSB::Entitlements::PaymentRequest.find_by(
            provider_key: "stripe",
            provider_ref: session.id
          )
          return pr if pr

          # Fallback: lookup by metadata
          if session.respond_to?(:metadata) && session.metadata&.respond_to?(:rsb_payment_request_id)
            pr_id = session.metadata.rsb_payment_request_id
            RSB::Entitlements::PaymentRequest.find_by(id: pr_id, provider_key: "stripe") if pr_id
          end
        end

        # Find Entitlement by subscription ID stored in provider_ref.
        #
        # @param subscription_id [String]
        # @return [RSB::Entitlements::Entitlement, nil]
        def self.find_entitlement_by_subscription(subscription_id)
          # First try: entitlement with provider_ref matching subscription ID
          entitlement = RSB::Entitlements::Entitlement.find_by(provider_ref: subscription_id)
          return entitlement if entitlement

          # Fallback: find via PaymentRequest
          pr = find_payment_request_by_subscription(subscription_id)
          pr&.entitlement
        end

        # Find PaymentRequest by subscription ID stored in provider_ref.
        #
        # @param subscription_id [String]
        # @return [RSB::Entitlements::PaymentRequest, nil]
        def self.find_payment_request_by_subscription(subscription_id)
          RSB::Entitlements::PaymentRequest.find_by(
            provider_key: "stripe",
            provider_ref: subscription_id
          )
        end

        # Find PaymentRequest by payment_intent_id stored in provider_data.
        # Uses in-memory filtering to support SQLite (which doesn't have JSON operators).
        #
        # @param payment_intent_id [String]
        # @return [RSB::Entitlements::PaymentRequest, nil]
        def self.find_payment_request_by_payment_intent(payment_intent_id)
          RSB::Entitlements::PaymentRequest
            .where(provider_key: "stripe")
            .find { |pr| pr.provider_data&.dig("payment_intent_id") == payment_intent_id }
        end

        # Store Stripe Customer ID on requestable's metadata for future checkouts.
        #
        # @param requestable [ActiveRecord::Base]
        # @param customer_id [String, nil]
        # @return [void]
        def self.store_customer_id(requestable, customer_id)
          return unless customer_id.present?
          return unless requestable.respond_to?(:metadata=)

          metadata = requestable.metadata || {}
          metadata["stripe_customer_id"] = customer_id
          requestable.update!(metadata: metadata)
        rescue => e
          Rails.logger.warn("#{LOG_TAG} Failed to store customer ID: #{e.message}")
        end

        # Revoke an entitlement if not already revoked.
        #
        # @param entitlement [RSB::Entitlements::Entitlement]
        # @param reason [String, Symbol]
        # @return [void]
        def self.revoke_entitlement(entitlement, reason:)
          return if entitlement.status == "revoked"

          entitlement.update!(
            status: "revoked",
            revoked_at: Time.current,
            revoke_reason: reason.to_s
          )
          fire_callback(:after_entitlement_changed, entitlement)
        end

        # Fire an RSB::Entitlements lifecycle callback.
        #
        # @param callback_name [Symbol]
        # @param record [ActiveRecord::Base]
        # @return [void]
        def self.fire_callback(callback_name, record)
          callback = RSB::Entitlements.configuration.send(callback_name)
          callback&.call(record)
        end
      end
    end
  end
end
