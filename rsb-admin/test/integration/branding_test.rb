require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
  end

  # --- Logo URL ---

  test "sidebar shows text app_name when logo_url is empty" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_match RSB::Admin.configuration.app_name, response.body
    assert_no_match "<img", response.body.split("<nav>").first  # no img in sidebar header area
  end

  test "sidebar shows logo img when logo_url is set" do
    RSB::Settings.set("admin.logo_url", "https://example.com/logo.svg")
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'src="https://example.com/logo.svg"', response.body
  end

  test "logo url is rendered as-is without processing" do
    RSB::Settings.set("admin.logo_url", "/assets/my-logo.png")
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'src="/assets/my-logo.png"', response.body
  end

  # --- Company Name ---

  test "login page does not show company name when empty" do
    get rsb_admin.login_path
    assert_response :success
    # Only the sign-in heading should be present, not a company name paragraph
    assert_select "p.text-rsb-muted", count: 0
  end

  test "login page shows company name when set" do
    RSB::Settings.set("admin.company_name", "Acme Corporation")
    get rsb_admin.login_path
    assert_response :success
    assert_match "Acme Corporation", response.body
  end

  # --- Footer ---

  test "layout does not render footer when footer_text is empty" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "footer", count: 0
  end

  test "layout renders footer when footer_text is set" do
    RSB::Settings.set("admin.footer_text", "© 2024 Acme Corp. All rights reserved.")
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "footer", text: /© 2024 Acme Corp/
  end

  # --- Empty strings = not set (Business Rule #4) ---

  test "empty company_name is treated as not set" do
    RSB::Settings.set("admin.company_name", "")
    get rsb_admin.login_path
    assert_response :success
    assert_select "p.text-rsb-muted", count: 0
  end

  test "empty logo_url is treated as not set" do
    RSB::Settings.set("admin.logo_url", "")
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    # Sidebar header should have text, not img
    assert_no_match '<img src=""', response.body
  end

  test "empty footer_text is treated as not set" do
    RSB::Settings.set("admin.footer_text", "")
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "footer", count: 0
  end

  # --- Login page with logo ---

  test "login page shows logo when logo_url is set" do
    RSB::Settings.set("admin.logo_url", "https://example.com/logo.svg")
    get rsb_admin.login_path
    assert_response :success
    assert_match 'src="https://example.com/logo.svg"', response.body
  end

  # --- Settings resolution chain (Business Rule #8) ---

  test "branding follows normal settings resolution chain" do
    # Initializer default is empty string
    assert_equal "", RSB::Settings.get("admin.company_name").to_s

    # DB override
    RSB::Settings.set("admin.company_name", "DB Company")
    assert_equal "DB Company", RSB::Settings.get("admin.company_name")
  end
end
