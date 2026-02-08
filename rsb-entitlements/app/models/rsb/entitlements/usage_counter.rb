module RSB
  module Entitlements
    class UsageCounter < ApplicationRecord
      belongs_to :countable, polymorphic: true
      belongs_to :plan, class_name: "RSB::Entitlements::Plan"

      validates :metric, presence: true,
                         uniqueness: { scope: [:countable_type, :countable_id, :period_key, :plan_id] }
      validates :period_key, presence: true
      validates :current_value, numericality: { greater_than_or_equal_to: 0 }

      scope :for_metric, ->(metric) { where(metric: metric.to_s) }
      scope :for_period, ->(period_key) { where(period_key: period_key.to_s) }
      scope :for_plan, ->(plan) { where(plan_id: plan.id) }
      scope :cumulative, -> { where(period_key: PeriodKeyCalculator::CUMULATIVE_KEY) }
      scope :recent, ->(n) { order(period_key: :desc).limit(n) }

      # Atomically increments the counter's current_value.
      #
      # Uses SQL UPDATE to ensure atomicity under concurrent access.
      # Fires the `after_usage_limit_reached` callback if the counter reaches its limit.
      #
      # @param amount [Integer] the amount to increment by (default: 1)
      # @return [Integer] the new current_value after increment
      def increment!(amount = 1)
        self.class.where(id: id).update_all(
          ["current_value = current_value + ?", amount]
        )
        reload
        check_limit_reached
        current_value
      end

      # Returns whether the counter has reached its limit.
      #
      # @return [Boolean] true if current_value >= limit, false if no limit set
      def at_limit?
        return false if limit.nil?
        current_value >= limit
      end

      # Returns the remaining quota before the limit is reached.
      #
      # @return [Integer, nil] remaining count, or nil if no limit (unlimited)
      def remaining
        return nil if limit.nil?
        [limit - current_value, 0].max
      end

      private

      def check_limit_reached
        return unless at_limit?
        callback = RSB::Entitlements.configuration.after_usage_limit_reached
        callback&.call(self)
      end
    end
  end
end
