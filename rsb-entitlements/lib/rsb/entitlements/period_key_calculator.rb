module RSB
  module Entitlements
    # Computes period keys for usage tracking from period types.
    #
    # Period keys are used to bucket usage records by time period:
    # - daily: "YYYY-MM-DD" (ISO 8601 date)
    # - weekly: "YYYY-WNN" (ISO 8601 week number, Monday start)
    # - monthly: "YYYY-MM"
    # - nil/empty: "__cumulative__" (lifetime/no reset)
    #
    # @example
    #   PeriodKeyCalculator.current_key("daily")
    #   # => "2026-02-13"
    #
    #   PeriodKeyCalculator.current_key("weekly", Time.new(2026, 2, 13))
    #   # => "2026-W07"
    #
    #   PeriodKeyCalculator.current_key(nil)
    #   # => "__cumulative__"
    module PeriodKeyCalculator
      # Constant for cumulative (non-resetting) period keys.
      CUMULATIVE_KEY = "__cumulative__"

      # Compute the period key for a given period type and time.
      #
      # @param period [String, Symbol, nil] The period type ("daily", "weekly", "monthly", or nil)
      # @param time [Time, ActiveSupport::TimeWithZone] The time to compute the key for (defaults to Time.current)
      # @return [String] The period key string
      #
      # @example Daily period
      #   current_key("daily", Time.new(2026, 2, 13, 10, 30, 0))
      #   # => "2026-02-13"
      #
      # @example Weekly period
      #   current_key("weekly", Time.new(2026, 2, 13, 10, 0, 0))
      #   # => "2026-W07"
      #
      # @example Monthly period
      #   current_key("monthly", Time.new(2026, 2, 13, 10, 0, 0))
      #   # => "2026-02"
      #
      # @example Cumulative period
      #   current_key(nil)
      #   # => "__cumulative__"
      def self.current_key(period, time = Time.current)
        case period&.to_s
        when "daily"   then time.strftime("%Y-%m-%d")
        when "weekly"  then time.strftime("%G-W%V")
        when "monthly" then time.strftime("%Y-%m")
        else CUMULATIVE_KEY
        end
      end
    end
  end
end
