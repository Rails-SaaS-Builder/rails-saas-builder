require "test_helper"

class ActionButtonPermissionsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "admin with only index permission sees disabled New button on roles index" do
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show"]
    })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success

    # New button should be disabled (no "new" permission)
    assert_select "a[href='#{rsb_admin.new_role_path}']", count: 0
    assert_select "span[title='No access']", minimum: 1
  end

  test "admin with full roles permissions sees active New button" do
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show", "new", "create", "edit", "update", "destroy"]
    })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success
    assert_select "a[href='#{rsb_admin.new_role_path}']"
  end

  test "admin without edit permission sees disabled edit icons on roles index" do
    role = RSB::Admin::Role.create!(name: "Target #{SecureRandom.hex(4)}", permissions: {})
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show"]
    })
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success

    # Edit icon should be disabled
    assert_select "a[href='#{rsb_admin.edit_role_path(role)}']", count: 0
  end

  test "admin without destroy permission sees disabled delete on role show" do
    role = RSB::Admin::Role.create!(name: "Target #{SecureRandom.hex(4)}", permissions: {})
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "roles" => ["index", "show", "edit", "update"]
    })
    sign_in_admin(admin)

    get rsb_admin.role_path(role)
    assert_response :success

    # Delete button should be disabled
    assert_select "form[action='#{rsb_admin.role_path(role)}'] input[name='_method'][value='delete']", count: 0
    assert_match "No access", response.body
  end

  test "admin without edit permission sees disabled edit button on admin_users show" do
    target_admin = create_test_admin!(superadmin: true)
    admin = create_test_admin!(permissions: {
      "dashboard" => ["index"],
      "admin_users" => ["index", "show"]
    })
    sign_in_admin(admin)

    get rsb_admin.admin_user_path(target_admin)
    assert_response :success

    # Edit button should be disabled
    assert_select "a[href='#{rsb_admin.edit_admin_user_path(target_admin)}']", count: 0
  end

  test "superadmin sees all buttons active" do
    target_role = RSB::Admin::Role.create!(name: "Target #{SecureRandom.hex(4)}", permissions: {})
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.roles_path
    assert_response :success
    assert_select "a[href='#{rsb_admin.new_role_path}']"
    assert_select "a[href='#{rsb_admin.edit_role_path(target_role)}']"
  end
end
