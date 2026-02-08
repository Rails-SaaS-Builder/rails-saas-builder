require "test_helper"

class AdminPlansTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    register_test_provider(key: :admin, label: "Admin")
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Index ---

  test "index lists plans with curated columns" do
    RSB::Entitlements::Plan.create!(
      name: "Pro", slug: "pro", interval: "monthly",
      price_cents: 2900, currency: "usd", active: true,
      features: { "sso" => true, "api" => false },
      limits: { "projects" => 10 }
    )

    get "/admin/plans"
    assert_response :success
    assert_match "Pro", response.body
    assert_match "monthly", response.body.downcase
  end

  test "index shows feature and limit counts" do
    RSB::Entitlements::Plan.create!(
      name: "Starter", slug: "starter", interval: "monthly",
      price_cents: 0, currency: "usd", active: true,
      features: { "api" => true }, limits: { "seats" => 5 }
    )

    get "/admin/plans"
    assert_response :success
    assert_match "1 feature", response.body.downcase
    assert_match "1 limit", response.body.downcase
  end

  # --- Show ---

  test "show displays plan details with feature badges" do
    plan = RSB::Entitlements::Plan.create!(
      name: "Enterprise", slug: "enterprise", interval: "yearly",
      price_cents: 99900, currency: "usd", active: true,
      features: { "sso" => true, "custom_branding" => false },
      limits: { "api_calls" => 100000 }
    )

    get "/admin/plans/#{plan.id}"
    assert_response :success
    assert_match "Enterprise", response.body
    assert_match "Sso", response.body          # feature name titleized
    assert_match "Enabled", response.body       # enabled badge
    assert_match "Disabled", response.body      # disabled badge
    assert_match "100,000", response.body       # limit value formatted with comma
  end

  # --- New / Create ---

  test "new renders the plan form" do
    get "/admin/plans/new"
    assert_response :success
    assert_match "Name", response.body
    assert_match "Add Feature", response.body
    assert_match "Add Limit", response.body
  end

  test "create with valid params including features and limits" do
    assert_difference "RSB::Entitlements::Plan.count", 1 do
      post "/admin/plans", params: {
        plan: {
          name: "Business",
          slug: "business",
          interval: "monthly",
          price_cents: 4900,
          currency: "usd",
          active: true,
          features: { "sso" => "true", "api_access" => "true" },
          limits: { "seats" => "25", "projects" => "50" }
        }
      }
    end

    plan = RSB::Entitlements::Plan.last
    assert_redirected_to "/admin/plans/#{plan.id}"
    assert_equal "Business", plan.name
    assert_equal({ "sso" => true, "api_access" => true }, plan.features)
    assert_equal({ "seats" => 25, "projects" => 50 }, plan.limits)
  end

  test "create with invalid params re-renders form" do
    post "/admin/plans", params: {
      plan: { name: "", slug: "", interval: "" }
    }
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "edit renders form with existing values" do
    plan = RSB::Entitlements::Plan.create!(
      name: "Pro", slug: "pro", interval: "monthly",
      price_cents: 2900, currency: "usd", active: true,
      features: { "sso" => true }, limits: { "seats" => 10 }
    )

    get "/admin/plans/#{plan.id}/edit"
    assert_response :success
    assert_match "Pro", response.body
    assert_match "sso", response.body
  end

  test "update changes plan attributes" do
    plan = RSB::Entitlements::Plan.create!(
      name: "Pro", slug: "pro", interval: "monthly",
      price_cents: 2900, currency: "usd", active: true,
      features: { "sso" => true }, limits: { "seats" => 10 }
    )

    patch "/admin/plans/#{plan.id}", params: {
      plan: {
        name: "Pro Plus",
        features: { "sso" => "true", "api" => "true" },
        limits: { "seats" => "25" }
      }
    }

    assert_redirected_to "/admin/plans/#{plan.id}"
    plan.reload
    assert_equal "Pro Plus", plan.name
    assert_equal({ "sso" => true, "api" => true }, plan.features)
    assert_equal({ "seats" => 25 }, plan.limits)
  end

  # --- Destroy ---

  test "destroy deletes plan with no entitlements" do
    plan = RSB::Entitlements::Plan.create!(
      name: "Temp", slug: "temp", interval: "monthly",
      price_cents: 100, currency: "usd", active: false
    )

    assert_difference "RSB::Entitlements::Plan.count", -1 do
      delete "/admin/plans/#{plan.id}"
    end

    assert_redirected_to "/admin/plans"
  end

  test "destroy refuses to delete plan with active entitlements" do
    plan = RSB::Entitlements::Plan.create!(
      name: "In Use", slug: "in-use", interval: "monthly",
      price_cents: 100, currency: "usd", active: true
    )

    # Create an entitlement attached to this plan
    identity = RSB::Auth::Identity.create!(status: "active")
    RSB::Entitlements::Entitlement.create!(
      entitleable: identity,
      plan: plan,
      status: "active",
      provider: "admin"
    )

    assert_no_difference "RSB::Entitlements::Plan.count" do
      delete "/admin/plans/#{plan.id}"
    end

    assert_redirected_to "/admin/plans"
    follow_redirect!
    assert_match "cannot delete", response.body.downcase
  end

  # --- RBAC ---

  test "restricted admin cannot access plans" do
    restricted = create_test_admin!(permissions: { "other" => ["index"] })
    sign_in_admin(restricted)

    get "/admin/plans"
    assert_includes [302, 403], response.status
  end
end
