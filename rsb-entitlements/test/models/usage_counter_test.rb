require "test_helper"

# This file is kept for backward-compatibility with existing test references.
# The main ledger tests are in test/models/usage_counter_ledger_test.rb.
# This file tests the core model behavior (increment, at_limit, remaining).

class RSB::Entitlements::UsageCounterTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    register_test_provider
    @org = Organization.create!(name: "Test Org")
    @plan = create_test_plan
  end

  def create_counter(**overrides)
    defaults = {
      countable: @org,
      metric: "projects",
      period_key: RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY,
      plan: @plan,
      current_value: 0,
      limit: 100
    }
    RSB::Entitlements::UsageCounter.create!(defaults.merge(overrides))
  end

  test "increment! increases current_value atomically" do
    counter = create_counter(current_value: 5)
    counter.increment!(3)
    assert_equal 8, counter.reload.current_value
  end

  test "at_limit? returns true at limit" do
    counter = create_counter(current_value: 100, limit: 100)
    assert counter.at_limit?
  end

  test "at_limit? returns false below limit" do
    counter = create_counter(current_value: 50, limit: 100)
    refute counter.at_limit?
  end

  test "at_limit? returns false with no limit" do
    counter = create_counter(current_value: 999, limit: nil)
    refute counter.at_limit?
  end

  test "remaining returns difference" do
    counter = create_counter(current_value: 30, limit: 100)
    assert_equal 70, counter.remaining
  end

  test "remaining returns 0 when over limit" do
    counter = create_counter(current_value: 150, limit: 100)
    assert_equal 0, counter.remaining
  end

  test "remaining returns nil when no limit" do
    counter = create_counter(current_value: 30, limit: nil)
    assert_nil counter.remaining
  end
end
