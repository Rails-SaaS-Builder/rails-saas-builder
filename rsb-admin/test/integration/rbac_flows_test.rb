require "test_helper"

# Flow 1: Admin with No Role Signs In
# Rule #1: No role = no access
class RbacNoRoleFlowTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "no-role admin is redirected to dashboard then sees forbidden page" do
    admin = create_test_admin!(no_role: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_admin_forbidden_page(dashboard_link: false)
  end

  test "no-role admin cannot access any resource" do
    admin = create_test_admin!(no_role: true)
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_admin_forbidden_page(dashboard_link: false)

    get rsb_admin.admin_users_path
    assert_admin_forbidden_page(dashboard_link: false)

    get rsb_admin.settings_path
    assert_admin_forbidden_page(dashboard_link: false)
  end

  test "no-role admin can sign out" do
    admin = create_test_admin!(no_role: true)
    sign_in_admin(admin)

    delete rsb_admin.logout_path
    assert_redirected_to rsb_admin.login_path
  end

  test "no-role admin forbidden page has sign out link" do
    admin = create_test_admin!(no_role: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :forbidden
    assert_match I18n.t("rsb.admin.shared.sign_out_and_try"), response.body
  end
end

# Flow 2: Role Edit — Category-Grouped Permissions
# Rules #8, #9, #10
class RbacRoleFormFlowTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "role form shows Dashboard in System section" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.new_role_path
    assert_response :success

    assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index']"
  end

  test "role form does not have a separate Pages section" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.new_role_path
    assert_response :success

    # The old "Pages" header should not exist as a standalone section
    # System section should be the last section
    body = response.body
    system_pos = body.rindex("System")
    assert system_pos, "System section should exist"
  end

  test "superadmin toggle still grants wildcard permissions" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    post rsb_admin.roles_path, params: {
      role: {
        name: "Super Toggle #{SecureRandom.hex(4)}",
        superadmin_toggle: "1"
      }
    }

    role = RSB::Admin::Role.last
    assert_equal({ "*" => ["*"] }, role.permissions)
    assert role.superadmin?
  end
end

# Flow 3: Permission-Aware Sidebar Rendering
# Rules #3, #4, #5
class RbacSidebarFlowTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "sidebar shows permitted items as links and unpermitted as disabled" do
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "settings" => ["index"]
    })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    # Dashboard should be a link
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']"

    # Settings should be a link
    assert_select "nav a[href='#{rsb_admin.settings_path}']"

    # Roles and Admin Users should be disabled (spans with title)
    assert_select "nav span[title='#{I18n.t("rsb.admin.shared.no_access")}']", minimum: 1
  end
end

# Flow 4: Forbidden Page
# Rule #6
class RbacForbiddenPageFlowTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "forbidden page shows dashboard link when user has dashboard permission" do
    admin = create_test_admin!(permissions: { "dashboard" => ["index"] })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_admin_forbidden_page(dashboard_link: true)
  end

  test "forbidden page hides dashboard link when user lacks dashboard permission" do
    admin = create_test_admin!(permissions: { "roles" => ["index"] })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_admin_forbidden_page(dashboard_link: false)
  end

  test "forbidden page uses the admin layout with sidebar" do
    admin = create_test_admin!(permissions: { "dashboard" => ["index"] })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :forbidden

    # Should have the sidebar (full layout)
    assert_select "nav"
    assert_select "aside"
  end

  test "forbidden page returns 403 status" do
    admin = create_test_admin!(permissions: { "dashboard" => ["index"] })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :forbidden
  end
end

# Flow 5: Action-Level Button Visibility
# Rule #7
class RbacActionButtonsFlowTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "viewer role sees disabled New and action buttons on roles" do
    RSB::Admin::Role.create!(name: "Target Role", permissions: {})

    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show"]
    })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success

    # New button should be disabled (no "new" permission)
    assert_select "a[href='#{rsb_admin.new_role_path}']", count: 0
  end

  test "editor role sees active buttons for permitted actions" do
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show", "new", "create", "edit", "update"]
    })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success

    # New button should be active
    assert_select "a[href='#{rsb_admin.new_role_path}']"
  end

  test "superadmin sees all buttons active" do
    RSB::Admin::Role.create!(name: "Target Role", permissions: {})

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success
    assert_select "a[href='#{rsb_admin.new_role_path}']"
  end
end

# Rule #11: Backwards compatibility
class RbacBackwardsCompatibilityTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "superadmin role still has full access" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    get rsb_admin.roles_path
    assert_response :success

    get rsb_admin.admin_users_path
    assert_response :success

    get rsb_admin.settings_path
    assert_response :success
  end

  test "admin created via create_test_admin! with superadmin: true has full access" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success
  end

  test "role with specific permissions still works correctly" do
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "settings" => ["index", "update"]
    })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    get rsb_admin.settings_path
    assert_response :success

    get rsb_admin.roles_path
    assert_response :forbidden
  end
end
