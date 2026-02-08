require "test_helper"

class PlanLimitsTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  def nested_plan(limits: {})
    create_test_plan(limits: limits)
  end

  # --- limit_for ---

  test "limit_for returns integer limit from nested config" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    assert_equal 1000, plan.limit_for("api_calls")
  end

  test "limit_for returns nil for undefined metric" do
    plan = nested_plan(limits: {})
    assert_nil plan.limit_for("api_calls")
  end

  test "limit_for returns nil when limit value is nil (unlimited)" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => nil, "period" => "daily" } })
    assert_nil plan.limit_for("api_calls")
  end

  test "limit_for accepts symbol key" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 500, "period" => "monthly" } })
    assert_equal 500, plan.limit_for(:api_calls)
  end

  # --- period_for ---

  test "period_for returns period string from nested config" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    assert_equal "daily", plan.period_for("api_calls")
  end

  test "period_for returns nil for cumulative metric" do
    plan = nested_plan(limits: { "projects" => { "limit" => 10, "period" => nil } })
    assert_nil plan.period_for("projects")
  end

  test "period_for returns nil for undefined metric" do
    plan = nested_plan(limits: {})
    assert_nil plan.period_for("api_calls")
  end

  test "period_for accepts symbol key" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "monthly" } })
    assert_equal "monthly", plan.period_for(:api_calls)
  end

  # --- limit_config_for ---

  test "limit_config_for returns full config hash" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    config = plan.limit_config_for("api_calls")
    assert_equal({ "limit" => 1000, "period" => "daily" }, config)
  end

  test "limit_config_for returns nil for undefined metric" do
    plan = nested_plan(limits: {})
    assert_nil plan.limit_config_for("api_calls")
  end

  test "limit_config_for accepts symbol key" do
    plan = nested_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    assert_instance_of Hash, plan.limit_config_for(:api_calls)
  end

  # --- multiple metrics ---

  test "plan with multiple metrics returns correct values for each" do
    plan = nested_plan(limits: {
      "api_calls" => { "limit" => 1000, "period" => "daily" },
      "projects"  => { "limit" => 10, "period" => nil },
      "storage_gb" => { "limit" => 50, "period" => "monthly" }
    })

    assert_equal 1000, plan.limit_for("api_calls")
    assert_equal "daily", plan.period_for("api_calls")
    assert_equal 10, plan.limit_for("projects")
    assert_nil plan.period_for("projects")
    assert_equal 50, plan.limit_for("storage_gb")
    assert_equal "monthly", plan.period_for("storage_gb")
  end
end
