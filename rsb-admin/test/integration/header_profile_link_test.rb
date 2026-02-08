require "test_helper"

class HeaderProfileLinkTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
  end

  test "header email is a link to profile page" do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "header a[href='#{rsb_admin.profile_path}']", text: @admin.email
  end

  test "profile link is visible for admin with no role" do
    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: nil
    )
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: no_role_admin.email, password: "password123" }

    get rsb_admin.profile_path
    assert_response :success
    assert_select "header a[href='#{rsb_admin.profile_path}']", text: no_role_admin.email
  end

  test "clicking profile link leads to profile page" do
    get rsb_admin.profile_path
    assert_response :success
    assert_match @admin.email, response.body
  end
end
