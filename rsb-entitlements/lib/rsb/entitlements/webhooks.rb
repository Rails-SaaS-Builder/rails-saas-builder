# frozen_string_literal: true

module RSB
  module Entitlements
    # Idempotent wrapper for provider webhook delivery. Adapter authors parse
    # the provider's payload and call {Subscriptions.sync!} / `subject.consume!`
    # from inside the block. The gem's only job here is to ensure each
    # `(provider, event_id)` is processed at most once.
    #
    # Behavior:
    #
    # 1. Wraps the call in `ActiveRecord::Base.transaction`.
    # 2. `INSERT`s a {ProviderEvent} row keyed by `(provider, event_id)`.
    #    On unique-index collision, returns `:already_processed` without
    #    invoking the block.
    # 3. Otherwise runs the block, commits the transaction, returns `:processed`.
    # 4. If the block raises, the transaction rolls back (including the
    #    `provider_events` row), so the next at-least-once delivery can retry.
    #
    # Webhook-level idempotency only — adapters that fan a single webhook out
    # into multiple `consume!` calls own dedup themselves.
    #
    # @example Typical Stripe adapter usage
    #   class StripeWebhooksController < ApplicationController
    #     def create
    #       event = Stripe::Webhook.construct_event(request.body.read,
    #                                               request.headers['Stripe-Signature'],
    #                                               ENV.fetch('STRIPE_WEBHOOK_SECRET'))
    #
    #       result = RSB::Entitlements::Webhooks.process(
    #         provider: 'stripe',
    #         event_id: event.id,
    #         type:     event.type,
    #         payload:  event.to_hash
    #       ) do
    #         StripeAdapter.handle(event) # may call Subscriptions.sync!, subject.consume!, etc.
    #       end
    #
    #       head(result == :processed ? :ok : :ok) # always 200 to ack delivery
    #     end
    #   end
    module Webhooks
      # @param provider [String, Symbol] e.g., `'stripe'`, `'apple'`, `'revenuecat'`
      # @param event_id [String] provider-supplied unique event identifier
      # @param type [String] provider event type, e.g., `'customer.subscription.updated'`
      # @param payload [Hash, nil] raw event payload (stored verbatim in jsonb)
      # @yield runs only on the first call for this `(provider, event_id)` pair
      # @return [Symbol] `:processed` when the block ran (or no block was given);
      #   `:already_processed` when the event was previously recorded
      def self.process(provider:, event_id:, type:, payload:)
        # requires_new: true ensures we always own a real savepoint (or BEGIN
        # in production). This is critical so that:
        #   (a) the inner savepoint around the INSERT can be rolled back cleanly
        #       without leaving the outer connection in PG's "aborted transaction"
        #       state, and
        #   (b) if the caller's block raises, AR rolls back to this savepoint,
        #       undoing the ProviderEvent insert and satisfying at-least-once
        #       retry semantics.
        ::ActiveRecord::Base.transaction(requires_new: true) do
          begin
            # Inner savepoint solely for the INSERT attempt. When the DB unique
            # index fires, AR issues ROLLBACK TO SAVEPOINT automatically before
            # re-raising RecordNotUnique — leaving the outer savepoint clean.
            #
            # save!(validate: false) bypasses the model-level presence/uniqueness
            # validators so the DB unique index is the sole collision detector.
            # This also permits `payload: {}` (a valid empty JSON object) which
            # would otherwise trip `validates :payload, presence: true` because
            # `{}.blank?` is true in Rails.
            ::ActiveRecord::Base.transaction(requires_new: true) do
              pe = ::RSB::Entitlements::ProviderEvent.new(
                provider: provider.to_s,
                event_id: event_id.to_s,
                type: type.to_s,
                payload: payload || {}
              )
              pe.save!(validate: false)
            end
          rescue ::ActiveRecord::RecordNotUnique
            # Duplicate delivery: skip the block, return short-circuit symbol.
            # The `return` exits the outer transaction block; AR commits the
            # savepoint (no-op, nothing was inserted) and re-joins the caller's
            # transaction cleanly.
            return :already_processed
          end

          yield if block_given?
          :processed
        end
      end
    end
  end
end
