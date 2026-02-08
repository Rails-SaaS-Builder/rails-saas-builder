require "test_helper"

class RSB::Entitlements::EntitlementExpirationJobTest < ActiveSupport::TestCase
  setup do
    register_test_provider(key: :admin, label: "Admin")
    @org = Organization.create!(name: "Test Org")
    @plan = create_test_plan
  end

  test "expires entitlements with expires_at in the past" do
    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @org, plan: @plan, status: "active",
      provider: "admin", activated_at: 2.months.ago,
      expires_at: 1.day.ago
    )

    RSB::Entitlements::EntitlementExpirationJob.perform_now

    assert_equal "expired", entitlement.reload.status
  end

  test "does not expire entitlements with future expires_at" do
    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @org, plan: @plan, status: "active",
      provider: "admin", activated_at: Time.current,
      expires_at: 1.month.from_now
    )

    RSB::Entitlements::EntitlementExpirationJob.perform_now

    assert_equal "active", entitlement.reload.status
  end

  test "does not expire already-expired entitlements" do
    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @org, plan: @plan, status: "expired",
      provider: "admin", expires_at: 1.day.ago
    )

    assert_nothing_raised do
      RSB::Entitlements::EntitlementExpirationJob.perform_now
    end

    assert_equal "expired", entitlement.reload.status
  end

  test "does not expire revoked entitlements" do
    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @org, plan: @plan, status: "revoked",
      provider: "admin", revoked_at: 2.days.ago, revoke_reason: "admin",
      expires_at: 1.day.ago
    )

    RSB::Entitlements::EntitlementExpirationJob.perform_now

    assert_equal "revoked", entitlement.reload.status
  end

  test "does not expire entitlements without expires_at" do
    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @org, plan: @plan, status: "active",
      provider: "admin", activated_at: Time.current,
      expires_at: nil
    )

    RSB::Entitlements::EntitlementExpirationJob.perform_now

    assert_equal "active", entitlement.reload.status
  end
end
