module RSB
  module Entitlements
    module Stripe
      class PaymentProvider < RSB::Entitlements::PaymentProvider::Base
        def self.provider_key
          :stripe
        end

        def self.provider_label
          "Stripe"
        end

        def self.manual_resolution?
          false
        end

        def self.admin_actions
          [:refund]
        end

        def self.refundable?
          true
        end

        settings_schema do
          setting :enabled,
                  type: :boolean,
                  default: false,
                  description: "Enable Stripe payment provider"

          setting :secret_key,
                  type: :string,
                  default: "",
                  encrypted: true,
                  depends_on: "entitlements.providers.stripe.enabled",
                  description: "Stripe secret API key (sk_live_... or sk_test_...)"

          setting :publishable_key,
                  type: :string,
                  default: "",
                  depends_on: "entitlements.providers.stripe.enabled",
                  description: "Stripe publishable key (pk_live_... or pk_test_...)"

          setting :webhook_secret,
                  type: :string,
                  default: "",
                  encrypted: true,
                  depends_on: "entitlements.providers.stripe.enabled",
                  description: "Webhook endpoint signing secret (whsec_...)"

          setting :success_url,
                  type: :string,
                  default: "",
                  depends_on: "entitlements.providers.stripe.enabled",
                  description: "URL to redirect after successful checkout (supports {CHECKOUT_SESSION_ID} placeholder)"

          setting :cancel_url,
                  type: :string,
                  default: "",
                  depends_on: "entitlements.providers.stripe.enabled",
                  description: "URL to redirect if customer cancels checkout"
        end

        # Start the Stripe Checkout Session flow.
        # Creates a Checkout Session via the Stripe API and returns a redirect URL.
        #
        # @return [Hash] { redirect_url: "https://checkout.stripe.com/..." }
        # @raise [ArgumentError] if plan has no stripe_price_id in metadata
        def initiate!
          plan = payment_request.plan
          stripe_price_id = plan.metadata&.dig("stripe_price_id")

          unless stripe_price_id.present?
            raise ArgumentError,
              "Plan '#{plan.slug}' has no stripe_price_id in metadata. " \
              "Set plan.metadata['stripe_price_id'] to a valid Stripe Price ID."
          end

          mode = checkout_mode(plan.interval)
          session_params = build_session_params(
            mode: mode,
            stripe_price_id: stripe_price_id,
            plan: plan
          )

          session = RSB::Entitlements::Stripe.client.v1.checkout.sessions.create(session_params)

          payment_request.update!(
            status: "processing",
            provider_ref: session.id,
            provider_data: (payment_request.provider_data || {}).merge(
              "checkout_session_id" => session.id,
              "mode" => mode
            )
          )

          { redirect_url: session.url }
        end

        # Finalize payment and grant entitlement. Called by webhook handlers
        # after checkout.session.completed.
        #
        # @param params [Hash] optional: { subscription_id:, customer_id:, payment_intent_id: }
        # @return [void]
        def complete!(params = {})
          return unless payment_request.actionable?

          entitlement = payment_request.requestable.grant_entitlement(
            plan: payment_request.plan,
            provider: payment_request.provider_key,
            metadata: payment_request.metadata
          )

          # For subscriptions, store the subscription ID on the entitlement
          # so lifecycle events (invoice.paid, subscription.updated/deleted) can find it.
          if params[:subscription_id].present?
            entitlement.update!(provider_ref: params[:subscription_id])
          end

          payment_request.update!(
            status: "approved",
            entitlement: entitlement
          )

          fire_callback(:after_payment_request_changed, payment_request)
        end

        # No-op: Stripe handles payment failures via webhooks.
        # There is no manual rejection flow for Stripe payments.
        #
        # @param params [Hash] unused
        # @return [void]
        def reject!(params = {})
          # Intentionally empty — Stripe payments are not manually rejected.
          # Failed payments are handled by invoice.payment_failed webhook.
        end

        # Refund an approved Stripe payment. Creates a Stripe Refund,
        # revokes the linked entitlement, and updates the PaymentRequest.
        #
        # For subscriptions: cancels the subscription + refunds the latest payment.
        #
        # @param params [Hash] unused
        # @return [void]
        def refund!(params = {})
          data = payment_request.provider_data || {}
          client = RSB::Entitlements::Stripe.client

          # Cancel subscription if applicable
          if data["subscription_id"].present?
            begin
              client.v1.subscriptions.cancel(data["subscription_id"])
            rescue ::Stripe::InvalidRequestError => e
              # Subscription may already be canceled — log and continue
              Rails.logger.warn("#{RSB::Entitlements::Stripe::LOG_TAG} Subscription cancel failed: #{e.message}")
            end
          end

          # Create refund if payment_intent_id is available
          if data["payment_intent_id"].present?
            refund = client.v1.refunds.create(payment_intent: data["payment_intent_id"])
            data["refund_id"] = refund.id
          end

          # Revoke linked entitlement
          if payment_request.entitlement.present?
            payment_request.requestable.revoke_entitlement(reason: :refund)
          end

          payment_request.update!(
            status: "refunded",
            provider_data: data
          )

          fire_callback(:after_payment_request_changed, payment_request)
        end

        # Provider-specific details for the admin show page.
        #
        # @return [Hash] { "Label" => "value", ... }
        def admin_details
          data = payment_request.provider_data || {}
          details = {}
          details["Mode"] = data["mode"]&.capitalize if data["mode"].present?
          details["Checkout Session"] = data["checkout_session_id"] if data["checkout_session_id"].present?
          details["Stripe Customer"] = data["customer_id"] if data["customer_id"].present?
          details["Subscription"] = data["subscription_id"] if data["subscription_id"].present?
          details["Payment Intent"] = data["payment_intent_id"] if data["payment_intent_id"].present?
          details["Invoice"] = data["invoice_id"] if data["invoice_id"].present?
          details["Refund"] = data["refund_id"] if data["refund_id"].present?
          details["Failure"] = data["failure_message"] if data["failure_message"].present?
          details
        end

        private

        # Map RSB plan interval to Stripe Checkout Session mode.
        #
        # @param interval [String] plan interval ("monthly", "yearly", "one_time", "lifetime")
        # @return [String] "payment" or "subscription"
        def checkout_mode(interval)
          case interval
          when "monthly", "yearly"
            "subscription"
          when "one_time", "lifetime"
            "payment"
          else
            "payment"
          end
        end

        # Build the params hash for Stripe Checkout Session creation.
        #
        # @param mode [String] "payment" or "subscription"
        # @param stripe_price_id [String] Stripe Price ID
        # @param plan [RSB::Entitlements::Plan]
        # @return [Hash]
        def build_session_params(mode:, stripe_price_id:, plan:)
          requestable = payment_request.requestable
          params = {
            mode: mode,
            line_items: [{ price: stripe_price_id, quantity: 1 }],
            success_url: setting("success_url"),
            cancel_url: setting("cancel_url"),
            metadata: {
              rsb_payment_request_id: payment_request.id.to_s,
              rsb_plan_id: plan.id.to_s,
              rsb_requestable_type: payment_request.requestable_type,
              rsb_requestable_id: payment_request.requestable_id.to_s
            }
          }

          # Subscription mode: copy metadata to subscription_data for lifecycle events
          if mode == "subscription"
            params[:subscription_data] = {
              metadata: {
                rsb_plan_id: plan.id.to_s,
                rsb_requestable_type: payment_request.requestable_type,
                rsb_requestable_id: payment_request.requestable_id.to_s
              }
            }
          end

          # Customer reuse: pass existing Stripe Customer ID or email
          resolve_customer(params, requestable)

          params
        end

        # Add customer or customer_email to session params.
        #
        # @param params [Hash] session creation params (mutated)
        # @param requestable [ActiveRecord::Base]
        # @return [void]
        def resolve_customer(params, requestable)
          # Try stored Stripe Customer ID first
          if requestable.respond_to?(:metadata) &&
             requestable.metadata.is_a?(Hash) &&
             requestable.metadata["stripe_customer_id"].present?
            params[:customer] = requestable.metadata["stripe_customer_id"]
            return
          end

          # Fall back to email hint
          if requestable.respond_to?(:billing_email) && requestable.billing_email.present?
            params[:customer_email] = requestable.billing_email
          end
        end

        # Read a Stripe provider setting.
        #
        # @param key [String] setting key (without provider prefix)
        # @return [Object]
        def setting(key)
          RSB::Settings.get("entitlements.providers.stripe.#{key}")
        end

        # Fire an RSB::Entitlements lifecycle callback if configured.
        #
        # @param callback_name [Symbol] e.g., :after_payment_request_changed
        # @param record [ActiveRecord::Base]
        # @return [void]
        def fire_callback(callback_name, record)
          callback = RSB::Entitlements.configuration.send(callback_name)
          callback&.call(record)
        end
      end
    end
  end
end
