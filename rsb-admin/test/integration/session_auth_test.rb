# frozen_string_literal: true

require 'test_helper'

class SessionAuthTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
  end

  test 'login creates an AdminSession record' do
    assert_difference 'RSB::Admin::AdminSession.count', 1 do
      post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    end

    admin_session = RSB::Admin::AdminSession.last
    assert_equal @admin.id, admin_session.admin_user_id
    assert_not_nil admin_session.session_token
    assert_not_nil admin_session.ip_address
    assert_not_nil admin_session.last_active_at
  end

  test 'login stores session_token in cookie session' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    assert_redirected_to rsb_admin.dashboard_path

    # Verify we can access protected pages (session is valid)
    get rsb_admin.dashboard_path
    assert_response :success
  end

  test 'failed login does not create AdminSession' do
    assert_no_difference 'RSB::Admin::AdminSession.count' do
      post rsb_admin.login_path, params: { email: @admin.email, password: 'wrong' }
    end
  end

  test 'logout destroys the AdminSession record' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    assert_equal 1, RSB::Admin::AdminSession.where(admin_user: @admin).count

    delete rsb_admin.logout_path
    assert_equal 0, RSB::Admin::AdminSession.where(admin_user: @admin).count
  end

  test 'logout redirects to login' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    delete rsb_admin.logout_path
    assert_redirected_to rsb_admin.login_path
  end

  test 'after logout, dashboard requires re-login' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    delete rsb_admin.logout_path

    get rsb_admin.dashboard_path
    assert_redirected_to rsb_admin.login_path
  end

  test 'session activity is tracked on requests' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    admin_session = RSB::Admin::AdminSession.last
    initial_time = admin_session.last_active_at

    travel 5.minutes do
      get rsb_admin.dashboard_path
      admin_session.reload
      assert admin_session.last_active_at > initial_time
    end
  end

  test 'multiple logins create multiple sessions' do
    # First login
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    assert_equal 1, @admin.admin_sessions.count

    # Simulate second login from different browser (reset session)
    reset!
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    assert_equal 2, @admin.admin_sessions.count
  end
end
