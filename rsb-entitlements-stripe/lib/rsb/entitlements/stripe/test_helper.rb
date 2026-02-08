require "ostruct"

module RSB
  module Entitlements
    module Stripe
      module TestHelper
        extend ActiveSupport::Concern

        included do
          setup do
            RSB::Entitlements::Stripe.reset!
            RSB::Entitlements::Stripe.configuration.skip_webhook_verification = true
          end

          teardown do
            RSB::Entitlements::Stripe.reset!
          end
        end

        # Register the Stripe provider with test-safe settings (fake keys).
        # Call this in test setup when you need the Stripe provider available.
        #
        # @return [void]
        def register_test_stripe_provider
          RSB::Settings.registry.register(RSB::Entitlements.settings_schema) unless settings_registered?
          RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider) unless stripe_registered?
          RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_fake_key")
          RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_fake_secret")
          RSB::Settings.set("entitlements.providers.stripe.success_url", "https://test.example.com/success")
          RSB::Settings.set("entitlements.providers.stripe.cancel_url", "https://test.example.com/cancel")
          RSB::Settings.set("entitlements.providers.stripe.enabled", true)
        end

        # Build a mock Stripe Checkout Session object.
        #
        # @param id [String] session ID (default: "cs_test_...")
        # @param url [String] checkout URL
        # @param mode [String] "payment" or "subscription"
        # @return [OpenStruct] mock session with id, url, mode
        def stub_stripe_checkout_session(id: nil, url: nil, mode: "payment")
          id ||= "cs_test_#{SecureRandom.hex(8)}"
          url ||= "https://checkout.stripe.com/pay/#{id}"
          OpenStruct.new(id: id, url: url, mode: mode)
        end

        # Simulate a Stripe webhook event by invoking the handler directly.
        # Bypasses signature verification (skip_webhook_verification is set in setup).
        #
        # @param event_type [String] Stripe event type (e.g., "checkout.session.completed")
        # @param data [Hash] event data.object fields
        # @return [void]
        def simulate_stripe_webhook(event_type, data = {})
          event = build_stripe_event(event_type, data)
          RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
        end

        # Build a Stripe::Event-like object for unit testing handlers directly.
        #
        # @param type [String] event type
        # @param data [Hash] event data.object fields
        # @return [Stripe::Event]
        def build_stripe_event(type, data = {})
          ::Stripe::Event.construct_from({
            "id" => "evt_test_#{SecureRandom.hex(8)}",
            "type" => type,
            "data" => { "object" => data.deep_stringify_keys }
          })
        end

        # Build a mock Stripe client that captures API calls for assertion.
        # Returns a client mock and a recorder hash.
        #
        # @param checkout_session [OpenStruct, nil] mock session to return from sessions.create
        # @param refund [OpenStruct, nil] mock refund to return from refunds.create
        # @return [Array(OpenStruct, Hash)] [mock_client, recorder]
        def build_mock_stripe_client(checkout_session: nil, refund: nil)
          recorder = { checkout_creates: [], refund_creates: [], subscription_cancels: [] }

          checkout_session ||= stub_stripe_checkout_session

          mock_sessions = Object.new
          mock_sessions.define_singleton_method(:create) do |params|
            recorder[:checkout_creates] << params
            checkout_session
          end

          mock_refunds = Object.new
          mock_refunds.define_singleton_method(:create) do |**params|
            recorder[:refund_creates] << params
            refund || OpenStruct.new(id: "re_test_#{SecureRandom.hex(4)}")
          end

          mock_subscriptions = Object.new
          mock_subscriptions.define_singleton_method(:cancel) do |sub_id|
            recorder[:subscription_cancels] << sub_id
          end

          mock_checkout = OpenStruct.new(sessions: mock_sessions)
          mock_v1 = OpenStruct.new(
            checkout: mock_checkout,
            refunds: mock_refunds,
            subscriptions: mock_subscriptions
          )
          mock_client = OpenStruct.new(v1: mock_v1)

          [mock_client, recorder]
        end

        # Temporarily replace the Stripe client with a mock for the duration of a block.
        # Silences method redefinition warnings on both stub and restore.
        #
        # @param mock_client [Object] mock client to use
        # @yield block of test code that uses the mock client
        def with_mock_stripe_client(mock_client)
          original = RSB::Entitlements::Stripe.method(:client)
          RSB::Entitlements::Stripe.singleton_class.silence_redefinition_of_method(:client)
          RSB::Entitlements::Stripe.define_singleton_method(:client) { mock_client }
          yield
        ensure
          RSB::Entitlements::Stripe.singleton_class.silence_redefinition_of_method(:client)
          RSB::Entitlements::Stripe.define_singleton_method(:client, &original)
        end

        private

        def settings_registered?
          RSB::Settings.get("entitlements.providers.stripe.enabled")
          true
        rescue
          false
        end

        def stripe_registered?
          RSB::Entitlements.providers.find(:stripe).present?
        rescue
          false
        end
      end
    end
  end
end
