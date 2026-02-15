# frozen_string_literal: true

module RSB
  module Entitlements
    class UsageCounterService
      # Creates usage counters for a newly activated entitlement.
      #
      # For each metric in the plan's limits, creates a counter with the correct
      # period_key and limit. Uses find_or_create_by! to avoid duplicates.
      #
      # @param entitlement [RSB::Entitlements::Entitlement] the activated entitlement
      # @return [void]
      def create_counters_for(entitlement)
        return unless entitlement.active?
        return unless RSB::Settings.get('entitlements.auto_create_counters')

        plan = entitlement.plan
        return if plan.limits.blank?

        plan.limits.each do |metric, config|
          next unless config.is_a?(Hash)

          period = config['period']
          limit_value = config['limit']
          period_key = PeriodKeyCalculator.current_key(period)

          entitlement.entitleable.usage_counters.find_or_create_by!(
            metric: metric.to_s,
            period_key: period_key,
            plan_id: plan.id
          ) do |counter|
            counter.limit = limit_value
          end
        end
      end

      # Handles usage counter transitions when an entitleable changes plans.
      #
      # For each metric in the new plan:
      # - If the period type changed: creates a fresh counter (value: 0)
      # - If the period type is the same:
      #   - "continue" mode: carries over current_value from old counter
      #   - "reset" mode: creates counter with value: 0
      # - New metrics get a fresh counter
      # - Removed metrics: old counters are left as historical records
      #
      # @param entitleable [Object] the entitleable record (e.g., Organization)
      # @param old_plan [RSB::Entitlements::Plan] the previous plan
      # @param new_plan [RSB::Entitlements::Plan] the new plan
      # @return [void]
      def handle_plan_change(entitleable, old_plan:, new_plan:)
        mode = begin
          RSB::Settings.get('entitlements.on_plan_change_usage')
        rescue StandardError
          'continue'
        end

        source = entitleable.respond_to?(:entitlement_source) ? entitleable.entitlement_source : entitleable

        new_plan.limits.each do |metric, new_config|
          next unless new_config.is_a?(Hash)

          new_period = new_config['period']
          new_limit = new_config['limit']
          new_period_key = PeriodKeyCalculator.current_key(new_period)

          old_config = old_plan.limit_config_for(metric)
          old_period = old_config&.dig('period')

          # Determine carry-over value
          carry_over = 0
          if old_config && old_period == new_period && mode == 'continue'
            old_period_key = PeriodKeyCalculator.current_key(old_period)
            old_counter = source.usage_counters
                                .for_metric(metric)
                                .for_period(old_period_key)
                                .for_plan(old_plan)
                                .last
            carry_over = old_counter&.current_value || 0
          end

          counter = source.usage_counters.find_or_initialize_by(
            metric: metric.to_s,
            period_key: new_period_key,
            plan_id: new_plan.id
          )
          counter.current_value = carry_over
          counter.limit = new_limit
          counter.save!
        end
      end
    end
  end
end
