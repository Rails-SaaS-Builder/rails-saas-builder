require "test_helper"

# Basic service tests. Comprehensive ledger tests are in usage_counter_service_ledger_test.rb.

class RSB::Entitlements::UsageCounterServiceTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    register_test_provider(key: :admin)
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    @org = Organization.create!(name: "Test Org")
    @service = RSB::Entitlements::UsageCounterService.new
  end

  test "create_counters_for creates counters from nested plan limits" do
    plan = create_test_plan(limits: {
      "api_calls" => { "limit" => 1000, "period" => "daily" },
      "projects" => { "limit" => 10, "period" => nil }
    })
    grant_test_entitlement(@org, plan: plan)

    assert @org.usage_counters.for_metric("api_calls").exists?
    assert @org.usage_counters.for_metric("projects").exists?
  end

  test "create_counters_for skips non-active entitlements" do
    plan = create_test_plan(limits: { "api_calls" => { "limit" => 1000, "period" => "daily" } })
    entitlement = grant_test_entitlement(@org, plan: plan)
    entitlement.revoke!(reason: "admin")

    @org.usage_counters.destroy_all
    @service.create_counters_for(entitlement)
    assert_equal 0, @org.usage_counters.count
  end
end
