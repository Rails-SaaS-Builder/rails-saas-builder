# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class PeriodCalculatorTest < ActiveSupport::TestCase
      # --- day ---

      test 'period: day, clock within first day → returns anchor (N=0)' do
        anchor = Time.utc(2026, 1, 15, 12, 0, 0)
        clock  = anchor + (0.5 * 86_400) # T + 0.5d
        assert_equal anchor,
                     PeriodCalculator.period_start_for(period: 'day', anchor: anchor, clock: clock)
      end

      test 'period: day, clock 1.5 days after anchor → returns anchor + 1 day (N=1)' do
        anchor = Time.utc(2026, 1, 15, 12, 0, 0)
        clock  = anchor + (1.5 * 86_400)
        expected = anchor + 86_400
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'day', anchor: anchor, clock: clock)
      end

      # --- week ---

      test 'period: week, clock 10 days after anchor → returns anchor + 7 days' do
        anchor = Time.utc(2026, 1, 15, 12, 0, 0)
        clock  = anchor + (10 * 86_400)
        expected = anchor + (7 * 86_400)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'week', anchor: anchor, clock: clock)
      end

      # --- month ---

      test 'period: month, clock just before next monthly boundary → returns anchor (N=0)' do
        anchor = Time.utc(2026, 1, 15, 14, 23, 0)
        clock  = Time.utc(2026, 2, 14, 23, 0, 0)
        assert_equal anchor,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      test 'period: month, clock exactly at boundary → returns boundary (N=1, equality holds)' do
        anchor = Time.utc(2026, 1, 15, 14, 23, 0)
        clock  = Time.utc(2026, 2, 15, 14, 23, 0)
        expected = Time.utc(2026, 2, 15, 14, 23, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      # --- end-of-month edge (Time#advance handles clamping) ---

      test 'period: month, anchor on 31st → February clamps to 28 (N=1)' do
        anchor = Time.utc(2026, 1, 31, 12, 0, 0)
        clock  = Time.utc(2026, 3, 15, 0, 0, 0)
        expected = Time.utc(2026, 2, 28, 12, 0, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      test 'period: month, anchor on 31st → March returns to 31 (N=2; advance is from anchor)' do
        anchor = Time.utc(2026, 1, 31, 12, 0, 0)
        clock  = Time.utc(2026, 3, 31, 12, 0, 0)
        expected = Time.utc(2026, 3, 31, 12, 0, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      test 'period: month, anchor on 31st → April clamps to 30 (N=3)' do
        anchor = Time.utc(2026, 1, 31, 12, 0, 0)
        clock  = Time.utc(2026, 5, 15, 0, 0, 0)
        expected = Time.utc(2026, 4, 30, 12, 0, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      # --- year ---

      test 'period: year → returns anchor + 1 year (N=1)' do
        anchor = Time.utc(2025, 4, 15, 14, 23, 0)
        clock  = Time.utc(2026, 6, 1, 0, 0, 0)
        expected = Time.utc(2026, 4, 15, 14, 23, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'year', anchor: anchor, clock: clock)
      end

      test 'period: year, leap-day anchor → non-leap year clamps to Feb 28' do
        anchor = Time.utc(2024, 2, 29, 12, 0, 0)
        clock  = Time.utc(2025, 3, 1, 0, 0, 0)
        expected = Time.utc(2025, 2, 28, 12, 0, 0)
        assert_equal expected,
                     PeriodCalculator.period_start_for(period: 'year', anchor: anchor, clock: clock)
      end

      # --- safety: clock < anchor ---

      test 'clock before anchor → returns anchor (N=0, defined behavior)' do
        anchor = Time.utc(2026, 6, 1, 0, 0, 0)
        clock  = Time.utc(2026, 5, 1, 0, 0, 0)
        assert_equal anchor,
                     PeriodCalculator.period_start_for(period: 'month', anchor: anchor, clock: clock)
      end

      # --- error cases ---

      test 'period: nil raises ArgumentError mentioning period' do
        anchor = Time.utc(2026, 1, 15, 12, 0, 0)
        err = assert_raises(ArgumentError) do
          PeriodCalculator.period_start_for(period: nil, anchor: anchor, clock: anchor)
        end
        assert_match(/period/, err.message)
      end

      test 'period: invalid string raises ArgumentError' do
        anchor = Time.utc(2026, 1, 15, 12, 0, 0)
        assert_raises(ArgumentError) do
          PeriodCalculator.period_start_for(period: 'fortnight', anchor: anchor, clock: anchor + 86_400)
        end
      end
    end
  end
end
