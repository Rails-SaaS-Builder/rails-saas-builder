require "test_helper"

class AdminLoginTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
  end

  test "GET /admin/login renders login form" do
    get rsb_admin.login_path
    assert_response :success
    assert_select "input[name='email']"
    assert_select "input[name='password']"
  end

  test "POST /admin/login with valid credentials redirects to dashboard" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    assert_redirected_to rsb_admin.dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "POST /admin/login records sign in" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    @admin.reload
    assert_not_nil @admin.last_sign_in_at
  end

  test "POST /admin/login with invalid credentials re-renders form" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "POST /admin/login with non-existent email re-renders form" do
    post rsb_admin.login_path, params: { email: "nobody@example.com", password: "whatever" }
    assert_response :unprocessable_entity
  end

  test "DELETE /admin/logout clears session and redirects" do
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
    delete rsb_admin.logout_path
    assert_redirected_to rsb_admin.login_path

    # After logout, dashboard should redirect to login
    get rsb_admin.dashboard_path
    assert_redirected_to rsb_admin.login_path
  end

  test "unauthenticated access to dashboard redirects to login" do
    get rsb_admin.dashboard_path
    assert_redirected_to rsb_admin.login_path
  end

  test "unauthenticated access to settings redirects to login" do
    get rsb_admin.settings_path
    assert_redirected_to rsb_admin.login_path
  end
end
