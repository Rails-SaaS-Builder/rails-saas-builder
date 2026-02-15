# frozen_string_literal: true

require 'test_helper'

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
  end

  test 'dashboard renders successfully' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select 'h1', 'Dashboard'
  end

  test 'dashboard shows customization guide when no override registered' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'Customize Your Dashboard', response.body
    assert_match 'register_dashboard', response.body
    assert_match 'Admin::DashboardController', response.body
  end

  test 'dashboard requires permission' do
    role = RSB::Admin::Role.create!(
      name: "Roles Only #{SecureRandom.hex(4)}",
      permissions: { 'roles' => ['index'] }
    )
    restricted = RSB::Admin::AdminUser.create!(
      email: "restricted-dash-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: role
    )

    post rsb_admin.login_path, params: { email: restricted.email, password: 'password123' }

    get rsb_admin.dashboard_path
    assert_response :forbidden
  end

  test 'dashboard accessible with dashboard permission' do
    role = RSB::Admin::Role.create!(
      name: "Dashboard Access #{SecureRandom.hex(4)}",
      permissions: { 'dashboard' => ['index'] }
    )
    admin = RSB::Admin::AdminUser.create!(
      email: "dashaccess-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: role
    )

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.dashboard_path
    assert_response :success
  end
end
