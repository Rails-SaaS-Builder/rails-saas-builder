require "test_helper"

class BreadcrumbsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
    @app_name = RSB::Admin.configuration.app_name
  end

  test "dashboard breadcrumbs: AppName > Dashboard" do
    get rsb_admin.dashboard_path
    assert_response :success

    # Root item links to dashboard
    assert_select "nav.flex a[href='#{rsb_admin.dashboard_path}']", text: @app_name

    # Dashboard as last item (bold, no link)
    assert_select "nav.flex span.font-medium", text: I18n.t("rsb.admin.dashboard.title")

    # 2 items = 1 chevron separator
    assert_select "nav.flex svg", count: 1
  end

  test "settings page breadcrumbs: AppName > System > Settings" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    get rsb_admin.settings_path
    assert_response :success

    # Root link
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name

    # System (intermediate, as span)
    assert_select "nav span", text: I18n.t("rsb.admin.shared.system")

    # Settings (last item)
    assert_select "nav span.font-medium", text: I18n.t("rsb.admin.settings.title")

    # 3 items = 2 chevron separators
    assert_select "nav svg", minimum: 2
  end

  test "admin users index breadcrumbs: AppName > System > Admin Users" do
    get rsb_admin.admin_users_path
    assert_response :success

    # Root link
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name

    # System
    assert_select "nav", text: /System/

    # Admin Users (last item)
    assert_select "nav span.font-medium", text: I18n.t("rsb.admin.admin_users.title")
  end

  test "admin users edit breadcrumbs include record ID and Edit" do
    other_admin = create_test_admin!(superadmin: true, email: "other@example.com")

    get rsb_admin.edit_admin_user_path(other_admin)
    assert_response :success

    # Root link
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name

    # Admin Users link (not last item)
    assert_select "nav a[href='#{rsb_admin.admin_users_path}']", text: I18n.t("rsb.admin.admin_users.title")

    # Record ID link
    assert_select "nav a[href='#{rsb_admin.admin_user_path(other_admin)}']", text: "##{other_admin.id}"

    # Edit (last item)
    assert_select "nav span.font-medium", text: I18n.t("rsb.admin.shared.edit")
  end

  test "roles index breadcrumbs: AppName > System > Roles" do
    get rsb_admin.roles_path
    assert_response :success

    # Root link
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name

    # System
    assert_select "nav", text: /System/

    # Roles (last item)
    assert_select "nav span.font-medium", text: I18n.t("rsb.admin.roles.title")
  end

  test "breadcrumb root always links to dashboard" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    get rsb_admin.settings_path
    assert_response :success

    # Root should be app_name and link to dashboard_path
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: @app_name
  end

  test "last breadcrumb has no link" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    get rsb_admin.settings_path
    assert_response :success

    # Last breadcrumb (Settings) should be a span with font-medium
    assert_select "nav.flex span.font-medium", text: I18n.t("rsb.admin.settings.title")

    # Should NOT be a link in breadcrumbs
    assert_select "nav.flex a", text: I18n.t("rsb.admin.settings.title"), count: 0
  end

  test "breadcrumb items separated by chevron-right icon" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    get rsb_admin.settings_path
    assert_response :success

    # With 3 items (AppName, System, Settings), should have 2 chevron separators
    assert_select "nav svg", minimum: 2
  end

  test "breadcrumbs helper is accessible in views" do
    get rsb_admin.dashboard_path
    assert_response :success

    assert_select "nav"
  end

  test "admin users new page has New breadcrumb" do
    get rsb_admin.new_admin_user_path
    assert_response :success

    assert_select "nav span.font-medium", text: /New Admin User/
  end

  test "roles edit page has Edit breadcrumb" do
    role = RSB::Admin::Role.create!(name: "Test Role", permissions: {})

    get rsb_admin.edit_role_path(role)
    assert_response :success

    assert_select "nav span.font-medium", text: I18n.t("rsb.admin.shared.edit")
  end

  test "breadcrumb root uses configured app_name" do
    original_name = RSB::Admin.configuration.app_name
    RSB::Admin.configuration.app_name = "My Custom App"

    get rsb_admin.dashboard_path
    assert_response :success

    assert_select "nav a[href='#{rsb_admin.dashboard_path}']", text: "My Custom App"
  ensure
    RSB::Admin.configuration.app_name = original_name
  end

  test "page controller inherits breadcrumbs via request.env" do
    RSB::Admin.registry.register_category "Testing" do
      page :breadcrumb_test_page,
        label: "Breadcrumb Test",
        icon: "file",
        controller: "test_breadcrumb",
        actions: [{ key: :index, label: "Overview" }]
    end

    get "/admin/breadcrumb_test_page"
    assert_response :success

    # Should show inherited breadcrumbs: AppName > Testing > Breadcrumb Test
    # Use the breadcrumb-specific nav selector (flex items-center gap-1)
    assert_select "nav.flex.items-center a[href='#{rsb_admin.dashboard_path}']", text: @app_name
    assert_select "nav.flex.items-center span", text: "Testing"
    assert_select "nav.flex.items-center span.font-medium", text: "Breadcrumb Test"
  end

  test "page action dispatched via Rack inherits breadcrumbs with page as link" do
    # Create a test controller with a custom action
    RSB::Admin.registry.register_category "Testing" do
      page :action_test_page,
        label: "Action Test",
        icon: "file",
        controller: "test_breadcrumb",
        actions: [
          { key: :index, label: "Overview" },
          { key: :custom, label: "Custom Action" }
        ]
    end

    # When accessing a page sub-action, the page label should be a link
    # (not the last breadcrumb item)
    get "/admin/action_test_page/custom"
    assert_response :success

    # Should show: AppName > Testing > Action Test (as link) > Custom Action
    # Use the breadcrumb-specific nav selector (flex items-center gap-1)
    assert_select "nav.flex.items-center a[href='#{rsb_admin.dashboard_path}']", text: @app_name
    assert_select "nav.flex.items-center span", text: "Testing"
    # Page label should be a link since we're in a sub-action
    assert_select "nav.flex.items-center a[href='/admin/action_test_page']", text: "Action Test"
    # Custom action should be the last item (no link)
    assert_select "nav.flex.items-center span.font-medium", text: "Custom Action"
  end
end
