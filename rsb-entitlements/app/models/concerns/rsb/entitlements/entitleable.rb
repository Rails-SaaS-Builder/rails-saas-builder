module RSB
  module Entitlements
    module Entitleable
      extend ActiveSupport::Concern

      included do
        has_many :entitlements,
                 class_name: "RSB::Entitlements::Entitlement",
                 as: :entitleable,
                 dependent: :restrict_with_error

        has_many :usage_counters,
                 class_name: "RSB::Entitlements::UsageCounter",
                 as: :countable,
                 dependent: :destroy

        has_many :payment_requests,
                 class_name: "RSB::Entitlements::PaymentRequest",
                 as: :requestable,
                 dependent: :restrict_with_error
      end

      def entitlement_source
        self
      end

      def current_entitlement
        entitlement_source.entitlements.active.order(created_at: :desc).first
      end

      def current_plan
        current_entitlement&.plan
      end

      def entitled_to?(feature)
        current_plan&.feature?(feature) || false
      end

      # Checks if the entitleable is within the usage limit for a metric
      # in the current period.
      #
      # @param metric [String, Symbol] the metric name
      # @return [Boolean] true if within limit or unlimited, false if at/over limit or no plan
      def within_limit?(metric)
        plan = current_plan
        return false unless plan

        config = plan.limit_config_for(metric)
        return true unless config  # metric not defined = unlimited

        limit_value = config["limit"]
        return true if limit_value.nil?  # nil limit = unlimited

        period_key = PeriodKeyCalculator.current_key(config["period"])
        counter = current_period_counter(metric, period_key, plan)
        return true unless counter

        counter.current_value < limit_value
      end

      # Returns the remaining usage quota for a metric in the current period.
      #
      # @param metric [String, Symbol] the metric name
      # @return [Integer, nil] remaining count, or nil if unlimited or no plan
      def remaining(metric)
        plan = current_plan
        return nil unless plan

        config = plan.limit_config_for(metric)
        return nil unless config

        limit_value = config["limit"]
        return nil if limit_value.nil?

        period_key = PeriodKeyCalculator.current_key(config["period"])
        counter = current_period_counter(metric, period_key, plan)
        return limit_value unless counter

        [limit_value - counter.current_value, 0].max
      end

      # Grants an entitlement for a plan, revoking the current one if any.
      #
      # @param plan [RSB::Entitlements::Plan] the plan to grant
      # @param provider [String, Symbol] the provider key
      # @param expires_at [Time, nil] optional expiration time
      # @param metadata [Hash] optional metadata
      # @return [RSB::Entitlements::Entitlement] the new entitlement
      def grant_entitlement(plan:, provider:, expires_at: nil, metadata: {})
        source = entitlement_source
        current = source.current_entitlement
        old_plan = current&.plan
        current&.revoke!(reason: "upgrade") if current

        new_entitlement = source.entitlements.create!(
          plan: plan,
          status: "active",
          provider: provider.to_s,
          activated_at: Time.current,
          expires_at: expires_at,
          metadata: metadata
        )

        # Handle plan change counter transitions if there was a previous plan
        if old_plan && old_plan.id != plan.id
          UsageCounterService.new.handle_plan_change(source, old_plan: old_plan, new_plan: plan)
        end

        new_entitlement
      end

      def revoke_entitlement(reason: "admin")
        entitlement_source.current_entitlement&.revoke!(reason: reason)
      end

      # Increments the usage counter for a metric in the current period.
      #
      # Automatically finds or creates the counter record for the current period
      # based on the plan's limit configuration.
      #
      # @param metric [String, Symbol] the metric name
      # @param amount [Integer] the amount to increment (default: 1)
      # @return [Integer] the new current_value
      # @raise [RuntimeError] if no current plan or metric not defined in plan
      def increment_usage(metric, amount = 1)
        source = entitlement_source
        plan = source.current_entitlement&.plan
        raise "No current plan for metric: #{metric}" unless plan

        config = plan.limit_config_for(metric.to_s)
        raise "No limit defined for metric: #{metric}" unless config

        period_key = PeriodKeyCalculator.current_key(config["period"])

        counter = source.usage_counters.find_or_create_by!(
          metric: metric.to_s,
          period_key: period_key,
          plan_id: plan.id
        ) { |c| c.limit = config["limit"] }

        counter.increment!(amount)
      end

      # Returns payment requests in actionable states (pending, processing).
      #
      # @return [ActiveRecord::Relation<PaymentRequest>]
      def pending_payment_requests
        payment_requests.where(status: %w[pending processing])
      end

      # Create a payment request and initiate the provider flow.
      #
      # @param plan [RSB::Entitlements::Plan] the plan to request
      # @param provider [Symbol, String] registered provider key
      # @param amount_cents [Integer, nil] override amount (defaults to plan.price_cents)
      # @param currency [String, nil] override currency (defaults to plan.currency)
      # @param metadata [Hash] arbitrary metadata
      # @return [Hash] provider response ({ instructions: }, { redirect_url: }, or { status: :completed })
      #   OR { error: :duplicate_request, existing: PaymentRequest } if duplicate
      # @raise [ArgumentError] if provider is not registered or not enabled
      def request_payment(plan:, provider:, amount_cents: nil, currency: nil, metadata: {})
        provider_key = provider.to_sym
        definition = RSB::Entitlements.providers.find(provider_key)

        raise ArgumentError, "Provider :#{provider_key} is not registered" unless definition

        enabled = RSB::Entitlements.providers.enabled.any? { |d| d.key == provider_key }
        raise ArgumentError, "Provider :#{provider_key} is disabled" unless enabled

        existing = payment_requests.actionable.find_by(plan: plan)
        return { error: :duplicate_request, existing: existing } if existing

        request = payment_requests.create!(
          plan: plan,
          provider_key: provider_key.to_s,
          amount_cents: amount_cents || plan.price_cents,
          currency: currency || plan.currency,
          metadata: metadata
        )

        provider_instance = definition.provider_class.new(request)
        provider_instance.initiate!
      end

      # Returns historical usage counter records for a metric, most recent first.
      #
      # @param metric [String, Symbol] the metric name
      # @param limit [Integer] maximum number of records to return (default: 30)
      # @return [ActiveRecord::Relation<UsageCounter>]
      def usage_history(metric, limit: 30)
        entitlement_source.usage_counters
                          .for_metric(metric.to_s)
                          .order(period_key: :desc)
                          .limit(limit)
      end

      private

      def current_period_counter(metric, period_key, plan)
        entitlement_source.usage_counters
                          .for_metric(metric.to_s)
                          .for_period(period_key)
                          .for_plan(plan)
                          .last
      end
    end
  end
end
