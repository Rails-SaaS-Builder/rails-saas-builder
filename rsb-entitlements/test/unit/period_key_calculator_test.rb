# frozen_string_literal: true

require 'test_helper'

class PeriodKeyCalculatorTest < ActiveSupport::TestCase
  test "CUMULATIVE_KEY is '__cumulative__'" do
    assert_equal '__cumulative__', RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY
  end

  # --- daily ---

  test 'current_key for daily returns ISO date string' do
    time = Time.new(2026, 2, 13, 10, 30, 0)
    assert_equal '2026-02-13', RSB::Entitlements::PeriodKeyCalculator.current_key('daily', time)
  end

  test 'current_key for daily at midnight boundary' do
    time = Time.new(2026, 1, 1, 0, 0, 0)
    assert_equal '2026-01-01', RSB::Entitlements::PeriodKeyCalculator.current_key('daily', time)
  end

  test 'current_key for daily at end of year' do
    time = Time.new(2026, 12, 31, 23, 59, 59)
    assert_equal '2026-12-31', RSB::Entitlements::PeriodKeyCalculator.current_key('daily', time)
  end

  # --- weekly ---

  test 'current_key for weekly returns ISO week string' do
    time = Time.new(2026, 2, 13, 10, 0, 0) # Friday, week 7
    assert_equal '2026-W07', RSB::Entitlements::PeriodKeyCalculator.current_key('weekly', time)
  end

  test 'current_key for weekly at year boundary' do
    # Jan 1 2026 is a Thursday — ISO week 1 of 2026
    time = Time.new(2026, 1, 1, 12, 0, 0)
    assert_equal '2026-W01', RSB::Entitlements::PeriodKeyCalculator.current_key('weekly', time)
  end

  test 'current_key for weekly uses ISO 8601 week numbering' do
    # Dec 29 2025 is a Monday — ISO week 1 of 2026
    time = Time.new(2025, 12, 29, 12, 0, 0)
    assert_equal '2026-W01', RSB::Entitlements::PeriodKeyCalculator.current_key('weekly', time)
  end

  # --- monthly ---

  test 'current_key for monthly returns year-month string' do
    time = Time.new(2026, 2, 13, 10, 0, 0)
    assert_equal '2026-02', RSB::Entitlements::PeriodKeyCalculator.current_key('monthly', time)
  end

  test 'current_key for monthly at year boundary' do
    time = Time.new(2026, 1, 1, 0, 0, 0)
    assert_equal '2026-01', RSB::Entitlements::PeriodKeyCalculator.current_key('monthly', time)
  end

  test 'current_key for monthly in December' do
    time = Time.new(2026, 12, 25, 12, 0, 0)
    assert_equal '2026-12', RSB::Entitlements::PeriodKeyCalculator.current_key('monthly', time)
  end

  # --- cumulative (nil period) ---

  test 'current_key for nil period returns CUMULATIVE_KEY' do
    assert_equal '__cumulative__', RSB::Entitlements::PeriodKeyCalculator.current_key(nil)
  end

  test 'current_key for empty string period returns CUMULATIVE_KEY' do
    assert_equal '__cumulative__', RSB::Entitlements::PeriodKeyCalculator.current_key('')
  end

  # --- symbol coercion ---

  test 'current_key accepts symbol period' do
    time = Time.new(2026, 2, 13, 10, 0, 0)
    assert_equal '2026-02-13', RSB::Entitlements::PeriodKeyCalculator.current_key(:daily, time)
  end

  # --- default time ---

  test 'current_key defaults to Time.current when no time given' do
    key = RSB::Entitlements::PeriodKeyCalculator.current_key('daily')
    assert_equal Time.current.strftime('%Y-%m-%d'), key
  end
end
