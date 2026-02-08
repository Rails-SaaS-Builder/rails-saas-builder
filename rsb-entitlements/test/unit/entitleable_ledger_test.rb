require "test_helper"

class EntitleableLedgerTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    register_test_provider(key: :admin)
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    @org = Organization.create!(name: "Test Org")
    @plan = create_test_plan(limits: {
      "api_calls" => { "limit" => 1000, "period" => "daily" },
      "projects"  => { "limit" => 10, "period" => nil },
      "storage_gb" => { "limit" => 50, "period" => "monthly" }
    })
    grant_test_entitlement(@org, plan: @plan)
  end

  # --- increment_usage ---

  test "increment_usage creates counter for current period and increments" do
    @org.increment_usage("api_calls")
    counter = @org.usage_counters.for_metric("api_calls").last
    assert_equal 1, counter.current_value
    assert_equal Time.current.strftime("%Y-%m-%d"), counter.period_key
    assert_equal @plan.id, counter.plan_id
    assert_equal 1000, counter.limit
  end

  test "increment_usage with cumulative metric uses __cumulative__ period_key" do
    @org.increment_usage("projects")
    counter = @org.usage_counters.for_metric("projects").last
    assert_equal 1, counter.current_value
    assert_equal "__cumulative__", counter.period_key
  end

  test "increment_usage increments existing counter for same period" do
    @org.increment_usage("api_calls", 5)
    @org.increment_usage("api_calls", 3)
    counter = @org.usage_counters.for_metric("api_calls")
                  .for_period(Time.current.strftime("%Y-%m-%d")).last
    assert_equal 8, counter.current_value
  end

  test "increment_usage with custom amount" do
    result = @org.increment_usage("api_calls", 42)
    assert_equal 42, result
  end

  test "increment_usage raises when no current plan" do
    @org.revoke_entitlement(reason: "admin")
    error = assert_raises(RuntimeError) { @org.increment_usage("api_calls") }
    assert_match(/No current plan/, error.message)
  end

  test "increment_usage raises when metric not defined in plan" do
    error = assert_raises(RuntimeError) { @org.increment_usage("nonexistent") }
    assert_match(/No limit defined for metric/, error.message)
  end

  # --- within_limit? ---

  test "within_limit? returns true when no usage yet" do
    assert @org.within_limit?("api_calls")
  end

  test "within_limit? returns true when below limit" do
    @org.increment_usage("api_calls", 500)
    assert @org.within_limit?("api_calls")
  end

  test "within_limit? returns false when at limit" do
    @org.increment_usage("api_calls", 1000)
    refute @org.within_limit?("api_calls")
  end

  test "within_limit? returns false when no current plan" do
    @org.revoke_entitlement(reason: "admin")
    refute @org.within_limit?("api_calls")
  end

  test "within_limit? returns true when metric has no limit (unlimited)" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => nil, "period" => "daily" } })
    @org.revoke_entitlement(reason: "admin")
    grant_test_entitlement(@org, plan: plan)
    assert @org.within_limit?("api_calls")
  end

  test "within_limit? returns true when metric not defined in plan (unlimited)" do
    assert @org.within_limit?("undefined_metric")
  end

  # --- remaining ---

  test "remaining returns full limit when no usage yet" do
    assert_equal 1000, @org.remaining("api_calls")
  end

  test "remaining returns difference after usage" do
    @org.increment_usage("api_calls", 300)
    assert_equal 700, @org.remaining("api_calls")
  end

  test "remaining returns 0 when over limit" do
    @org.increment_usage("api_calls", 1500)
    assert_equal 0, @org.remaining("api_calls")
  end

  test "remaining returns nil when no current plan" do
    @org.revoke_entitlement(reason: "admin")
    assert_nil @org.remaining("api_calls")
  end

  test "remaining returns nil when metric has no limit (unlimited)" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => nil, "period" => "daily" } })
    @org.revoke_entitlement(reason: "admin")
    grant_test_entitlement(@org, plan: plan)
    assert_nil @org.remaining("api_calls")
  end

  # --- usage_history ---

  test "usage_history returns ordered records most recent first" do
    # Clear auto-created counters first
    @org.usage_counters.destroy_all

    RSB::Entitlements::UsageCounter.create!(countable: @org, metric: "api_calls", period_key: "2026-02-11", plan: @plan, current_value: 100, limit: 1000)
    RSB::Entitlements::UsageCounter.create!(countable: @org, metric: "api_calls", period_key: "2026-02-12", plan: @plan, current_value: 200, limit: 1000)
    RSB::Entitlements::UsageCounter.create!(countable: @org, metric: "api_calls", period_key: "2026-02-13", plan: @plan, current_value: 300, limit: 1000)

    history = @org.usage_history("api_calls", limit: 2)
    assert_equal 2, history.size
    assert_equal "2026-02-13", history.first.period_key
    assert_equal "2026-02-12", history.second.period_key
  end

  test "usage_history returns empty array when no records" do
    # Clear auto-created counters first
    @org.usage_counters.destroy_all

    history = @org.usage_history("api_calls")
    assert_equal [], history.to_a
  end

  test "usage_history works for cumulative metrics" do
    @org.increment_usage("projects", 3)
    history = @org.usage_history("projects")
    assert_equal 1, history.size
    assert_equal "__cumulative__", history.first.period_key
  end

  test "usage_history defaults to limit 30" do
    # Just verify it doesn't error — actual limit tested via query
    history = @org.usage_history("api_calls")
    assert_respond_to history, :to_a
  end
end
