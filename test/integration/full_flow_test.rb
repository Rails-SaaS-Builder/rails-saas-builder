require "test_helper"

class FullFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    register_test_provider(key: :admin, label: "Admin")
    Rails.cache.clear
  end

  test "registration → login → entitlement → feature check → usage tracking" do
    # Step 1: Register a new user
    RSB::Settings.set("auth.credentials.email_password.verification_required", false)
    RSB::Settings.set("auth.credentials.email_password.auto_verify_on_signup", true)

    assert_difference ["RSB::Auth::Identity.count", "RSB::Auth::Credential.count"], 1 do
      post registration_path, params: {
        identifier: "user@example.com",
        password: "secure123456",
        password_confirmation: "secure123456",
        credential_type: "email_password"
      }
    end

    identity = RSB::Auth::Identity.last
    assert identity, "Identity should have been created"
    assert_equal "active", identity.status

    # Step 2: Login
    post session_path, params: {
      identifier: "user@example.com",
      password: "secure123456"
    }
    assert_response :redirect
    assert cookies[:rsb_session_token].present?

    # Step 3: Create a plan and grant entitlement
    plan = RSB::Entitlements::Plan.create!(
      name: "Pro",
      slug: "pro",
      interval: "monthly",
      price_cents: 2900,
      currency: "usd",
      features: { "api_access" => true, "custom_branding" => true },
      limits: { "projects" => { "limit" => 10, "period" => nil } },
      active: true
    )

    # Identity includes Entitleable (via dummy app's initializer)
    identity.grant_entitlement(plan: plan, provider: "admin")

    # Step 4: Check features
    assert identity.entitled_to?("api_access")
    assert identity.entitled_to?("custom_branding")
    refute identity.entitled_to?("nonexistent")

    # Step 5: Check limits
    assert identity.within_limit?("projects")
    assert_equal 10, identity.remaining("projects")

    # Step 6: Increment usage
    identity.increment_usage("projects", 8)
    assert_equal 2, identity.remaining("projects")
    assert identity.within_limit?("projects")

    identity.increment_usage("projects", 2)
    refute identity.within_limit?("projects")
    assert_equal 0, identity.remaining("projects")
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
