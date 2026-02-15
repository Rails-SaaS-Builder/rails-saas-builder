# frozen_string_literal: true

module RSB
  module Entitlements
    module TestHelper
      extend ActiveSupport::Concern

      included do
        setup do
          RSB::Entitlements.reset!
        end

        teardown do
          RSB::Entitlements.reset!
        end
      end

      def create_test_plan(name: 'Test Plan', slug: nil, **overrides)
        slug ||= "test-plan-#{SecureRandom.hex(4)}"
        RSB::Entitlements::Plan.create!({
          name: name,
          slug: slug,
          interval: 'monthly',
          price_cents: 1000,
          currency: 'usd',
          features: {},
          limits: {},
          metadata: {},
          active: true
        }.merge(overrides))
      end

      def grant_test_entitlement(entitleable, plan: nil, provider: 'admin')
        plan ||= create_test_plan
        entitleable.grant_entitlement(plan: plan, provider: provider)
      end

      # Register a minimal test provider for use in tests.
      # Returns the provider class.
      #
      # @param key [Symbol] provider key (default: :test)
      # @param label [String] provider label (default: "Test Provider")
      # @param manual_resolution [Boolean] (default: false)
      # @param admin_actions [Array<Symbol>] (default: [])
      # @param refundable [Boolean] (default: false)
      # @param initiate_result [Hash] what initiate! returns (default: { status: :completed })
      # @return [Class] the provider class
      def register_test_provider(
        key: :test,
        label: 'Test Provider',
        manual_resolution: false,
        admin_actions: [],
        refundable: false,
        initiate_result: { status: :completed }
      )
        provider_class = Class.new(RSB::Entitlements::PaymentProvider::Base) do
          define_singleton_method(:provider_key) { key }
          define_singleton_method(:provider_label) { label }
          define_singleton_method(:manual_resolution?) { manual_resolution }
          define_singleton_method(:admin_actions) { admin_actions }
          define_singleton_method(:refundable?) { refundable }

          define_method(:initiate!) { initiate_result }
          define_method(:complete!) { |_params = {}| nil }
          define_method(:reject!) { |_params = {}| nil }
        end

        RSB::Entitlements.providers.register(provider_class)
        provider_class
      end

      # Create a test payment request.
      #
      # @param requestable [ActiveRecord::Base] the polymorphic owner
      # @param plan [RSB::Entitlements::Plan] the plan
      # @param provider_key [String] provider key (default: "wire")
      # @param status [String] status (default: "pending")
      # @return [RSB::Entitlements::PaymentRequest]
      def create_test_payment_request(requestable:, plan:, provider_key: 'wire', status: 'pending', **overrides)
        RSB::Entitlements::PaymentRequest.create!({
          requestable: requestable,
          plan: plan,
          provider_key: provider_key.to_s,
          status: status,
          amount_cents: plan.price_cents,
          currency: plan.currency,
          provider_data: {},
          metadata: {}
        }.merge(overrides))
      end

      # Create a test usage counter.
      #
      # @param countable [ActiveRecord::Base] the polymorphic owner
      # @param metric [String] metric name
      # @param plan [RSB::Entitlements::Plan] the plan
      # @param period_key [String] period key (default: "__cumulative__")
      # @param current_value [Integer] current usage value (default: 0)
      # @param limit [Integer, nil] usage limit
      # @return [RSB::Entitlements::UsageCounter]
      def create_test_usage_counter(countable:, metric:, plan:, period_key: '__cumulative__', current_value: 0,
                                    limit: nil)
        RSB::Entitlements::UsageCounter.create!(
          countable: countable,
          metric: metric.to_s,
          plan: plan,
          period_key: period_key,
          current_value: current_value,
          limit: limit
        )
      end
    end
  end
end
