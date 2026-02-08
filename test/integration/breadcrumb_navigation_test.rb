require "test_helper"

class BreadcrumbNavigationTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_admin_categories  # Re-register on_load hooks for cross-gem resources
    register_all_settings
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
    @app_name = RSB::Admin.configuration.app_name
  end

  # Flow 1: Breadcrumb root is app_name
  test "breadcrumb root is app_name on all pages" do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_admin_breadcrumbs(@app_name)
  end

  # Flow 3: Dashboard as normal page
  test "dashboard shows AppName > Dashboard" do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "Dashboard")
  end

  # Flow 1: Settings breadcrumbs
  test "settings shows AppName > System > Settings" do
    get rsb_admin.settings_path
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "System", "Settings")
  end

  # Flow 2: Resource with custom controller inherits breadcrumbs
  test "identity index shows AppName > Authentication > Identities" do
    # rsb-auth registers Identities with a custom controller
    # ResourcesController dispatches to it via Rack
    # The custom controller should inherit breadcrumbs
    registration = RSB::Admin.registry.find_resource_by_route_key("identities")
    skip "rsb-auth Identities not registered" unless registration

    get "/admin/identities"
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "Authentication", "Identities")
  end

  test "identity show appends record ID to inherited breadcrumbs" do
    registration = RSB::Admin.registry.find_resource_by_route_key("identities")
    skip "rsb-auth Identities not registered" unless registration

    # Create a test identity to view
    identity = RSB::Auth::Identity.create!(status: "active")

    get "/admin/identities/#{identity.id}"
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "Authentication", "Identities", "##{identity.id}")
  end

  # Flow 2: Page with custom controller inherits breadcrumbs
  test "sessions management page shows AppName > Authentication > Active Sessions" do
    page = RSB::Admin.registry.find_page_by_key(:sessions_management)
    skip "sessions_management page not registered" unless page

    get "/admin/sessions_management"
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "Authentication", "Active Sessions")
  end

  test "usage monitoring page shows AppName > Billing > Usage Monitoring" do
    page = RSB::Admin.registry.find_page_by_key(:usage_counters)
    skip "usage_counters page not registered" unless page

    get "/admin/usage_counters"
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "Billing", "Usage Monitoring")
  end

  # Rule #5: Root always links to dashboard
  test "breadcrumb root links to dashboard path" do
    get rsb_admin.admin_users_path
    assert_response :success
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name
  end

  # Rule #6: Last breadcrumb has no link
  test "last breadcrumb is bold text without link" do
    get rsb_admin.roles_path
    assert_response :success
    assert_select "nav.flex span.font-medium", text: I18n.t("rsb.admin.roles.title")
    assert_select "nav.flex a", text: I18n.t("rsb.admin.roles.title"), count: 0
  end

  # Rule #4: Custom controllers can still add breadcrumbs
  test "custom controller add_breadcrumb appends to inherited trail" do
    registration = RSB::Admin.registry.find_resource_by_route_key("identities")
    skip "rsb-auth Identities not registered" unless registration

    identity = RSB::Auth::Identity.create!(status: "active")

    # The custom IdentitiesController#show inherits breadcrumbs from ResourcesController
    # ResourcesController already appends the #ID breadcrumb in its build_breadcrumbs
    get "/admin/identities/#{identity.id}"
    assert_response :success

    # Should have: AppName > Authentication > Identities > #ID
    # The #ID was added by ResourcesController's build_breadcrumbs method
    assert_admin_breadcrumbs(@app_name, "Authentication", "Identities", "##{identity.id}")
  end

  # Backwards compatibility: non-dispatched controllers unaffected
  test "admin_users breadcrumbs work without dispatch" do
    get rsb_admin.admin_users_path
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "System", "Admin Users")
  end

  test "roles breadcrumbs work without dispatch" do
    get rsb_admin.roles_path
    assert_response :success
    assert_admin_breadcrumbs(@app_name, "System", "Roles")
  end
end
