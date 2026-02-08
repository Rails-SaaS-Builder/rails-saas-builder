require "test_helper"

class RSB::Entitlements::EntitleableTest < ActiveSupport::TestCase
  setup do
    # Register providers needed for existing tests
    register_test_provider(key: :admin, label: "Admin")

    @org = Organization.create!(name: "Test Org")
    @plan = create_test_plan(
      features: { "api_access" => true, "custom_branding" => false },
      limits: {
        "projects" => { "limit" => 10, "period" => nil },
        "storage_gb" => { "limit" => 100, "period" => nil }
      }
    )
  end

  test "current_plan returns the active entitlement's plan" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    assert_equal @plan, @org.current_plan
  end

  test "current_plan returns nil when no active entitlement" do
    assert_nil @org.current_plan
  end

  test "current_plan returns nil when only expired entitlements exist" do
    entitlement = @org.grant_entitlement(plan: @plan, provider: "admin")
    entitlement.expire!

    assert_nil @org.current_plan
  end

  test "entitled_to? returns true for enabled features" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    assert @org.entitled_to?("api_access")
  end

  test "entitled_to? returns false for disabled features" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    refute @org.entitled_to?("custom_branding")
  end

  test "entitled_to? returns false when no plan" do
    refute @org.entitled_to?("api_access")
  end

  test "entitled_to? returns false for unknown features" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    refute @org.entitled_to?("nonexistent")
  end

  test "within_limit? returns true when under limit" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    @org.usage_counters.create!(
      metric: "projects",
      current_value: 5,
      limit: 10,
      period_key: RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY,
      plan: @plan
    )

    assert @org.within_limit?("projects")
  end

  test "within_limit? returns false when at limit" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    @org.usage_counters.create!(
      metric: "projects",
      current_value: 10,
      limit: 10,
      period_key: RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY,
      plan: @plan
    )

    refute @org.within_limit?("projects")
  end

  test "within_limit? returns true when no counter exists" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    assert @org.within_limit?("projects")
  end

  test "within_limit? returns true when plan has no limit for metric" do
    plan_no_limits = create_test_plan(limits: {})
    @org.grant_entitlement(plan: plan_no_limits, provider: "admin")

    assert @org.within_limit?("projects")
  end

  test "within_limit? returns false when no plan" do
    refute @org.within_limit?("projects")
  end

  test "remaining returns remaining quota" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    @org.usage_counters.create!(
      metric: "projects",
      current_value: 7,
      limit: 10,
      period_key: RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY,
      plan: @plan
    )

    assert_equal 3, @org.remaining("projects")
  end

  test "remaining returns full limit when no counter exists" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    assert_equal 10, @org.remaining("projects")
  end

  test "remaining returns nil when plan has no limit for metric" do
    plan_no_limits = create_test_plan(limits: {})
    @org.grant_entitlement(plan: plan_no_limits, provider: "admin")

    assert_nil @org.remaining("projects")
  end

  test "remaining returns nil when no plan" do
    assert_nil @org.remaining("projects")
  end

  test "grant_entitlement creates a new active entitlement" do
    entitlement = @org.grant_entitlement(plan: @plan, provider: "admin")

    assert entitlement.persisted?
    assert_equal "active", entitlement.status
    assert_equal @plan, entitlement.plan
    assert_equal "admin", entitlement.provider
  end

  test "grant_entitlement revokes the old entitlement when granting a new one" do
    old_plan = create_test_plan(name: "Old Plan")
    old_entitlement = @org.grant_entitlement(plan: old_plan, provider: "admin")
    new_entitlement = @org.grant_entitlement(plan: @plan, provider: "admin")

    assert_equal "revoked", old_entitlement.reload.status
    assert_equal "active", new_entitlement.status
  end

  test "grant_entitlement with expires_at" do
    expires = 1.month.from_now
    entitlement = @org.grant_entitlement(plan: @plan, provider: "admin", expires_at: expires)

    assert_in_delta expires, entitlement.expires_at, 1.second
  end

  test "revoke_entitlement revokes current entitlement" do
    entitlement = @org.grant_entitlement(plan: @plan, provider: "admin")
    @org.revoke_entitlement(reason: "refund")

    assert_equal "revoked", entitlement.reload.status
    assert_equal "refund", entitlement.revoke_reason
  end

  test "revoke_entitlement does nothing when no current entitlement" do
    assert_nothing_raised do
      @org.revoke_entitlement(reason: "admin")
    end
  end

  test "increment_usage increments the counter" do
    @org.grant_entitlement(plan: @plan, provider: "admin")
    @org.usage_counters.create!(
      metric: "projects",
      current_value: 3,
      limit: 10,
      period_key: RSB::Entitlements::PeriodKeyCalculator::CUMULATIVE_KEY,
      plan: @plan
    )

    result = @org.increment_usage("projects")
    assert_equal 4, result
  end

  test "entitleable concern works on Organization model (not Identity)" do
    assert Organization.ancestors.map(&:name).any? { |n| n&.include?("Entitleable") }
  end

  test "has_many entitlements association" do
    assert_respond_to @org, :entitlements
  end

  test "has_many usage_counters association" do
    assert_respond_to @org, :usage_counters
  end

  # -- payment_requests association --

  test "payment_requests returns associated payment requests" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "PR Assoc Org")
    create_test_payment_request(requestable: org, plan: plan)

    assert_equal 1, org.payment_requests.count
  end

  # -- pending_payment_requests --

  test "pending_payment_requests returns pending and processing requests" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "Pending PR Org")

    pending_req = create_test_payment_request(requestable: org, plan: plan, status: "pending")
    processing_req = create_test_payment_request(
      requestable: org,
      plan: create_test_plan(slug: "plan-proc"),
      status: "processing"
    )
    approved_req = create_test_payment_request(
      requestable: org,
      plan: create_test_plan(slug: "plan-appr"),
      status: "approved"
    )

    pending = org.pending_payment_requests
    assert_includes pending, pending_req
    assert_includes pending, processing_req
    assert_not_includes pending, approved_req
  end

  # -- request_payment --

  test "request_payment creates PaymentRequest and calls initiate!" do
    register_test_provider(
      key: :wire,
      label: "Wire Transfer",
      manual_resolution: true,
      initiate_result: { instructions: "Pay here" }
    )
    plan = create_test_plan(price_cents: 5000, currency: "usd")
    org = Organization.create!(name: "Request Payment Org")

    result = org.request_payment(plan: plan, provider: :wire)

    assert_equal({ instructions: "Pay here" }, result)
    assert_equal 1, org.payment_requests.count

    req = org.payment_requests.last
    assert_equal "wire", req.provider_key
    assert_equal 5000, req.amount_cents
    assert_equal "usd", req.currency
    assert_equal plan, req.plan
  end

  test "request_payment uses plan price and currency as defaults" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan(price_cents: 7500, currency: "eur")
    org = Organization.create!(name: "Default Amount Org")

    org.request_payment(plan: plan, provider: :wire)
    req = org.payment_requests.last

    assert_equal 7500, req.amount_cents
    assert_equal "eur", req.currency
  end

  test "request_payment allows overriding amount_cents and currency" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan(price_cents: 5000, currency: "usd")
    org = Organization.create!(name: "Override Org")

    org.request_payment(plan: plan, provider: :wire, amount_cents: 9999, currency: "gbp")
    req = org.payment_requests.last

    assert_equal 9999, req.amount_cents
    assert_equal "gbp", req.currency
  end

  test "request_payment passes metadata to payment request" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "Metadata Org")

    org.request_payment(plan: plan, provider: :wire, metadata: { "ref" => "abc123" })
    req = org.payment_requests.last

    assert_equal({ "ref" => "abc123" }, req.metadata)
  end

  test "request_payment raises ArgumentError for unregistered provider" do
    plan = create_test_plan
    org = Organization.create!(name: "Bad Provider Org")

    assert_raises(ArgumentError) do
      org.request_payment(plan: plan, provider: :nonexistent)
    end
  end

  test "request_payment raises ArgumentError for disabled provider" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "Disabled Org")

    with_settings("entitlements.providers.wire.enabled" => false) do
      assert_raises(ArgumentError) do
        org.request_payment(plan: plan, provider: :wire)
      end
    end
  end

  test "request_payment returns error hash for duplicate actionable request" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "Duplicate Org")

    org.request_payment(plan: plan, provider: :wire)
    result = org.request_payment(plan: plan, provider: :wire)

    assert_equal :duplicate_request, result[:error]
    assert_not_nil result[:existing]
  end

  test "request_payment allows new request after previous is resolved" do
    register_test_provider(key: :wire, label: "Wire")
    plan = create_test_plan
    org = Organization.create!(name: "Resolved Org")

    org.request_payment(plan: plan, provider: :wire)
    org.payment_requests.last.update!(status: "rejected")

    result = org.request_payment(plan: plan, provider: :wire)
    assert_not result.key?(:error), "Expected no error for new request after resolution"
  end

  test "request_payment handles instant completion (status: :completed)" do
    register_test_provider(
      key: :instant,
      label: "Instant",
      initiate_result: { status: :completed }
    )
    plan = create_test_plan
    org = Organization.create!(name: "Instant Org")

    result = org.request_payment(plan: plan, provider: :instant)

    assert_equal({ status: :completed }, result)
  end
end
