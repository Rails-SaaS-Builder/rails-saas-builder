require "test_helper"

class UsageCounterServiceLedgerTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    register_test_provider(key: :admin)
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    @org = Organization.create!(name: "Test Org")
    @service = RSB::Entitlements::UsageCounterService.new
  end

  # --- create_counters_for ---

  test "create_counters_for creates periodic counter with correct period_key" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    entitlement = grant_test_entitlement(@org, plan: plan)

    # Clear auto-created counters and re-run
    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)

    counter = @org.usage_counters.for_metric("api_calls").last
    assert_not_nil counter
    assert_equal Time.current.strftime("%Y-%m-%d"), counter.period_key
    assert_equal plan.id, counter.plan_id
    assert_equal 1000, counter.limit
  end

  test "create_counters_for creates cumulative counter with __cumulative__ period_key" do
    plan = create_test_plan(limits: { "projects" => { "limit" => 10, "period" => nil } })
    entitlement = grant_test_entitlement(@org, plan: plan)

    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)

    counter = @org.usage_counters.for_metric("projects").last
    assert_equal "__cumulative__", counter.period_key
    assert_equal 10, counter.limit
  end

  test "create_counters_for does not duplicate existing counters" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    entitlement = grant_test_entitlement(@org, plan: plan)

    # Run twice
    @service.create_counters_for(entitlement)
    count_before = @org.usage_counters.count
    @service.create_counters_for(entitlement)
    assert_equal count_before, @org.usage_counters.count
  end

  test "create_counters_for respects auto_create_counters setting" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Settings.set("entitlements.auto_create_counters", false)

    plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    entitlement = grant_test_entitlement(@org, plan: plan)

    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)
    assert_equal 0, @org.usage_counters.count
  ensure
    RSB::Settings.set("entitlements.auto_create_counters", true) rescue nil
  end

  test "create_counters_for skips when entitlement not active" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    entitlement = grant_test_entitlement(@org, plan: plan)
    entitlement.revoke!(reason: "admin")

    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)
    assert_equal 0, @org.usage_counters.count
  end

  test "create_counters_for skips when plan has no limits" do
    plan = create_test_plan(limits: {})
    entitlement = grant_test_entitlement(@org, plan: plan)

    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)
    assert_equal 0, @org.usage_counters.count
  end

  # --- handle_plan_change ---

  test "handle_plan_change with continue mode carries over current_value" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Settings.set("entitlements.on_plan_change_usage", "continue")

    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "monthly" } })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("api_calls", 500)

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 5000, "period" => "monthly" } })

    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    new_counter = @org.usage_counters.for_metric("api_calls").for_plan(new_plan).last
    assert_not_nil new_counter
    assert_equal 500, new_counter.current_value  # carried over
    assert_equal 5000, new_counter.limit
  end

  test "handle_plan_change with reset mode starts at zero" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Settings.set("entitlements.on_plan_change_usage", "reset")

    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "monthly" } })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("api_calls", 500)

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 5000, "period" => "monthly" } })

    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    new_counter = @org.usage_counters.for_metric("api_calls").for_plan(new_plan).last
    assert_not_nil new_counter
    assert_equal 0, new_counter.current_value  # reset
    assert_equal 5000, new_counter.limit
  end

  test "handle_plan_change with period type change always creates fresh counter" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Settings.set("entitlements.on_plan_change_usage", "continue")

    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 100, "period" => "daily" } })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("api_calls", 50)

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 10000, "period" => "monthly" } })

    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    new_counter = @org.usage_counters.for_metric("api_calls").for_plan(new_plan).last
    assert_not_nil new_counter
    assert_equal 0, new_counter.current_value  # fresh start on period change
    assert_equal Time.current.strftime("%Y-%m"), new_counter.period_key
  end

  test "handle_plan_change preserves old counters as history" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)

    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "monthly" } })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("api_calls", 500)

    old_counter = @org.usage_counters.for_metric("api_calls").for_plan(old_plan).last

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 5000, "period" => "monthly" } })
    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    # Old counter still exists
    assert_equal 500, old_counter.reload.current_value
  end

  test "handle_plan_change creates counters for new metrics" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)

    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    grant_test_entitlement(@org, plan: old_plan)

    new_plan = create_test_plan(limits: {
      "api_calls" => { "limit" => 5000, "period" => "daily" },
      "storage_gb" => { "limit" => 100, "period" => nil }
    })

    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    storage_counter = @org.usage_counters.for_metric("storage_gb").for_plan(new_plan).last
    assert_not_nil storage_counter
    assert_equal 0, storage_counter.current_value
    assert_equal "__cumulative__", storage_counter.period_key
  end

  test "handle_plan_change leaves removed metrics as-is" do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)

    old_plan = create_test_plan(limits: {
      "api_calls" => { "limit" => 1000, "period" => "daily" },
      "projects" => { "limit" => 10, "period" => nil }
    })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("projects", 5)

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 5000, "period" => "daily" } })
    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    # projects counter still exists for old plan
    projects_counter = @org.usage_counters.for_metric("projects").for_plan(old_plan).last
    assert_equal 5, projects_counter.current_value
  end

  test "handle_plan_change defaults to continue when setting not registered" do
    old_plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "monthly" } })
    grant_test_entitlement(@org, plan: old_plan)
    @org.increment_usage("api_calls", 500)

    new_plan = create_test_plan(limits: { "api_calls" => { "limit" => 5000, "period" => "monthly" } })

    @service.handle_plan_change(@org, old_plan: old_plan, new_plan: new_plan)

    new_counter = @org.usage_counters.for_metric("api_calls").for_plan(new_plan).last
    assert_equal 500, new_counter.current_value  # carried over (continue is default)
  end
end
