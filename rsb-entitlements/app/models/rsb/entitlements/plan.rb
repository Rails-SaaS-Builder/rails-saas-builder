module RSB
  module Entitlements
    class Plan < ApplicationRecord
      INTERVALS = %w[monthly yearly lifetime one_time].freeze

      has_many :entitlements, dependent: :restrict_with_error
      has_many :usage_counters, dependent: :restrict_with_error

      validates :name, presence: true
      validates :slug, presence: true,
                       uniqueness: true,
                       format: { with: /\A[a-z0-9_-]+\z/ }
      validates :interval, presence: true, inclusion: { in: INTERVALS }
      validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :currency, presence: true

      scope :active, -> { where(active: true) }

      def free?
        price_cents == 0
      end

      def feature?(key)
        features[key.to_s] == true
      end

      # Returns the integer limit value for a metric from the nested limits config.
      #
      # @param key [String, Symbol] The metric key (e.g., "api_calls")
      # @return [Integer, nil] The limit value, or nil if undefined or unlimited
      #
      # @example
      #   plan.limit_for("api_calls")  # => 1000
      #   plan.limit_for(:projects)    # => 10
      #   plan.limit_for("undefined")  # => nil
      def limit_for(key)
        config = limits[key.to_s]
        return nil unless config.is_a?(Hash)
        config["limit"]
      end

      # Returns the period type for a metric from the nested limits config.
      #
      # @param key [String, Symbol] The metric key (e.g., "api_calls")
      # @return [String, nil] The period type ("daily", "weekly", "monthly"), or nil for cumulative
      #
      # @example
      #   plan.period_for("api_calls")  # => "daily"
      #   plan.period_for(:projects)    # => nil (cumulative)
      #   plan.period_for("undefined")  # => nil
      def period_for(key)
        config = limits[key.to_s]
        return nil unless config.is_a?(Hash)
        config["period"]
      end

      # Returns the full limit configuration hash for a metric.
      #
      # @param key [String, Symbol] The metric key (e.g., "api_calls")
      # @return [Hash, nil] The full config hash with "limit" and "period" keys, or nil if undefined
      #
      # @example
      #   plan.limit_config_for("api_calls")
      #   # => { "limit" => 1000, "period" => "daily" }
      #
      #   plan.limit_config_for("projects")
      #   # => { "limit" => 10, "period" => nil }
      #
      #   plan.limit_config_for("undefined")
      #   # => nil
      def limit_config_for(key)
        config = limits[key.to_s]
        return nil unless config.is_a?(Hash)
        config
      end
    end
  end
end
