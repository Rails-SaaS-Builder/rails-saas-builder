# frozen_string_literal: true

module RSB
  module Entitlements
    # Computes the start `Time` of the current usage period for a gauge,
    # given the entitlement's anchor (grant time), the period type, and a clock.
    #
    # v1 semantics: usage periods are anchored to the entitlement grant time —
    # NOT to calendar boundaries. Walking forward from `anchor` by N period
    # units gives the period-start `Time` such that the next step would exceed
    # `clock`. `Time#advance` is used so that month/year arithmetic clamps
    # end-of-month and leap-day edge cases correctly (Jan 31 + 1 month → Feb 28
    # or Feb 29 depending on the year; Feb 29 + 1 year → Feb 28).
    #
    # Pure module — no DB access, safe to call from anywhere on the call path.
    #
    # @example Daily gauge granted at noon, clock 1.5 days later
    #   PeriodCalculator.period_start_for(
    #     period: 'day',
    #     anchor: Time.utc(2026, 1, 15, 12, 0),
    #     clock:  Time.utc(2026, 1, 16, 18, 0)
    #   )
    #   # => 2026-01-16 12:00 UTC
    #
    # @example Monthly gauge with end-of-month clamping
    #   PeriodCalculator.period_start_for(
    #     period: 'month',
    #     anchor: Time.utc(2026, 1, 31, 12, 0),
    #     clock:  Time.utc(2026, 3, 15, 0, 0)
    #   )
    #   # => 2026-02-28 12:00 UTC
    module PeriodCalculator
      # Compute the start of the current period for a gauge.
      #
      # @param period [String, Symbol] one of 'day', 'week', 'month', 'year'
      # @param anchor [Time] the entitlement grant time (period zero start)
      # @param clock  [Time] the reference time (typically `Time.current`)
      # @return [Time] the start of the period containing `clock`, anchored to `anchor`
      # @raise [ArgumentError] if `period` is nil or not one of the supported values
      def self.period_start_for(period:, anchor:, clock:)
        raise ArgumentError, 'gauge has no period (period must be one of day/week/month/year)' if period.nil?
        return anchor if clock <= anchor

        case period.to_s
        when 'day'   then advance_until(:days,   1, anchor, clock)
        when 'week'  then advance_until(:days,   7, anchor, clock)
        when 'month' then advance_until(:months, 1, anchor, clock)
        when 'year'  then advance_until(:years,  1, anchor, clock)
        else raise ArgumentError, "invalid period: #{period.inspect} (must be day/week/month/year)"
        end
      end

      # Walks forward from `anchor` by (N+1)*step units of `unit` (passed to
      # `Time#advance`) until the next step would exceed `clock`, returning
      # the last value that did not exceed it.
      #
      # Always advances from `anchor` (not from the previous result) so that
      # month/year clamping is consistent — e.g. Jan 31 + 2 months = Mar 31,
      # not Feb 28 + 1 month = Mar 28.
      #
      # @api private
      def self.advance_until(unit, step, anchor, clock)
        n = 0
        result = anchor
        loop do
          next_t = anchor.advance(unit => (n + 1) * step)
          break if next_t > clock

          n += 1
          result = next_t
        end
        result
      end
      private_class_method :advance_until
    end
  end
end
