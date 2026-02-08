require "test_helper"

class UsageCounterLedgerTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    register_test_provider
    @org = Organization.create!(name: "Test Org")
    @plan = create_test_plan(limits: {
      "api_calls" => { "limit" => 1000, "period" => "daily" },
      "projects" => { "limit" => 10, "period" => nil }
    })
  end

  def create_counter(metric:, period_key:, plan: @plan, current_value: 0, limit: nil)
    RSB::Entitlements::UsageCounter.create!(
      countable: @org,
      metric: metric,
      period_key: period_key,
      plan: plan,
      current_value: current_value,
      limit: limit
    )
  end

  # --- validations ---

  test "validates presence of metric" do
    counter = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: nil, period_key: "__cumulative__", plan: @plan
    )
    refute counter.valid?
    assert_includes counter.errors[:metric], "can't be blank"
  end

  test "validates presence of period_key" do
    counter = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: "test", period_key: nil, plan: @plan
    )
    refute counter.valid?
    assert_includes counter.errors[:period_key], "can't be blank"
  end

  test "validates uniqueness of metric scoped to countable, period_key, and plan" do
    create_counter(metric: "api_calls", period_key: "2026-02-13", plan: @plan)
    dup = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: "api_calls", period_key: "2026-02-13", plan: @plan
    )
    refute dup.valid?
  end

  test "allows same metric and period_key with different plan" do
    other_plan = create_test_plan(name: "Other")
    create_counter(metric: "api_calls", period_key: "2026-02-13", plan: @plan)
    counter = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: "api_calls", period_key: "2026-02-13", plan: other_plan,
      current_value: 0
    )
    assert counter.valid?
  end

  test "allows same metric and plan with different period_key" do
    create_counter(metric: "api_calls", period_key: "2026-02-13")
    counter = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: "api_calls", period_key: "2026-02-14", plan: @plan,
      current_value: 0
    )
    assert counter.valid?
  end

  test "validates current_value is non-negative" do
    counter = RSB::Entitlements::UsageCounter.new(
      countable: @org, metric: "test", period_key: "__cumulative__",
      plan: @plan, current_value: -1
    )
    refute counter.valid?
  end

  # --- associations ---

  test "belongs_to plan" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13")
    assert_equal @plan, counter.plan
  end

  test "belongs_to countable (polymorphic)" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13")
    assert_equal @org, counter.countable
  end

  # --- scopes ---

  test "for_metric scope filters by metric" do
    c1 = create_counter(metric: "api_calls", period_key: "2026-02-13")
    c2 = create_counter(metric: "projects", period_key: "__cumulative__")
    results = RSB::Entitlements::UsageCounter.for_metric("api_calls")
    assert_includes results, c1
    assert_not_includes results, c2
  end

  test "for_period scope filters by period_key" do
    counter_1 = create_counter(metric: "api_calls", period_key: "2026-02-13")
    counter_2 = create_counter(metric: "api_calls", period_key: "2026-02-14")
    results = RSB::Entitlements::UsageCounter.for_period("2026-02-13")
    assert_includes results, counter_1
    assert_not_includes results, counter_2
  end

  test "for_plan scope filters by plan" do
    other_plan = create_test_plan(name: "Other")
    c1 = create_counter(metric: "api_calls", period_key: "2026-02-13", plan: @plan)
    c2 = create_counter(metric: "api_calls", period_key: "2026-02-13", plan: other_plan)
    results = RSB::Entitlements::UsageCounter.for_plan(@plan)
    assert_includes results, c1
    assert_not_includes results, c2
  end

  test "cumulative scope filters by __cumulative__ period_key" do
    c1 = create_counter(metric: "projects", period_key: "__cumulative__")
    c2 = create_counter(metric: "api_calls", period_key: "2026-02-13")
    results = RSB::Entitlements::UsageCounter.cumulative
    assert_includes results, c1
    assert_not_includes results, c2
  end

  test "recent scope orders by period_key desc and limits" do
    _oldest = create_counter(metric: "api_calls", period_key: "2026-02-11")
    newest = create_counter(metric: "api_calls", period_key: "2026-02-13")
    middle = create_counter(metric: "api_calls", period_key: "2026-02-12")
    results = RSB::Entitlements::UsageCounter.for_metric("api_calls").recent(2)
    assert_equal [newest, middle], results.to_a
  end

  # --- increment! ---

  test "increment! atomically increments current_value" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", limit: 100)
    result = counter.increment!(5)
    assert_equal 5, result
    assert_equal 5, counter.reload.current_value
  end

  test "increment! fires after_usage_limit_reached callback when at limit" do
    callback_fired = false
    RSB::Entitlements.configuration.after_usage_limit_reached = ->(c) { callback_fired = true }
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", current_value: 99, limit: 100)
    counter.increment!(1)
    assert callback_fired
  ensure
    RSB::Entitlements.configuration.after_usage_limit_reached = nil
  end

  # --- at_limit? / remaining ---

  test "at_limit? returns true when current_value >= limit" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", current_value: 100, limit: 100)
    assert counter.at_limit?
  end

  test "at_limit? returns false when no limit" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", current_value: 999, limit: nil)
    refute counter.at_limit?
  end

  test "remaining returns difference between limit and current_value" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", current_value: 30, limit: 100)
    assert_equal 70, counter.remaining
  end

  test "remaining returns nil when no limit" do
    counter = create_counter(metric: "api_calls", period_key: "2026-02-13", current_value: 30, limit: nil)
    assert_nil counter.remaining
  end
end
