# frozen_string_literal: true

require 'test_helper'

class AuthorizationTest < ActionDispatch::IntegrationTest
  test 'superadmin can access all resources' do
    role = RSB::Admin::Role.create!(name: "Super-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    admin = RSB::Admin::AdminUser.create!(email: "super-#{SecureRandom.hex(4)}@example.com", password: 'password123',
                                          password_confirmation: 'password123', role: role)

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.roles_path
    assert_response :success

    get rsb_admin.settings_path
    assert_response :success

    get rsb_admin.dashboard_path
    assert_response :success
  end

  test 'restricted role is denied access to unauthorized resources' do
    role = RSB::Admin::Role.create!(name: "Restricted-#{SecureRandom.hex(4)}", permissions: {
                                      'dashboard' => ['index']
                                    })
    admin = RSB::Admin::AdminUser.create!(email: "restricted-#{SecureRandom.hex(4)}@example.com",
                                          password: 'password123', password_confirmation: 'password123', role: role)

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    # Dashboard should work
    get rsb_admin.dashboard_path
    assert_response :success

    # Roles should be forbidden
    get rsb_admin.roles_path
    assert_response :forbidden

    # Settings should be forbidden
    get rsb_admin.settings_path
    assert_response :forbidden
  end

  test 'role with specific permissions can access allowed resources' do
    role = RSB::Admin::Role.create!(name: "RoleManager-#{SecureRandom.hex(4)}", permissions: {
                                      'dashboard' => ['index'],
                                      'roles' => %w[index show],
                                      'settings' => ['index']
                                    })
    admin = RSB::Admin::AdminUser.create!(email: "rolemanager-#{SecureRandom.hex(4)}@example.com",
                                          password: 'password123', password_confirmation: 'password123', role: role)

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.roles_path
    assert_response :success

    get rsb_admin.settings_path
    assert_response :success

    # Cannot create roles
    get rsb_admin.new_role_path
    assert_response :forbidden
  end

  test 'admin without role is denied access (no role = no access)' do
    admin = RSB::Admin::AdminUser.create!(email: "norole-auth-#{SecureRandom.hex(4)}@example.com",
                                          password: 'password123', password_confirmation: 'password123')

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.dashboard_path
    assert_response :forbidden
  end

  test 'forbidden response renders the forbidden page with proper content' do
    admin = RSB::Admin::AdminUser.create!(email: "norole-forbidden-#{SecureRandom.hex(4)}@example.com",
                                          password: 'password123', password_confirmation: 'password123')

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.dashboard_path
    assert_response :forbidden
    assert_match 'Access Denied', response.body
    assert_match 'You don&#39;t have permission', response.body
  end

  test 'forbidden page hides dashboard link when user has no dashboard permission' do
    admin = RSB::Admin::AdminUser.create!(email: "norole-nodash-#{SecureRandom.hex(4)}@example.com",
                                          password: 'password123', password_confirmation: 'password123')

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.roles_path
    assert_response :forbidden
    refute_match 'Go to Dashboard', response.body
  end

  test 'forbidden page shows dashboard link when user has dashboard permission' do
    role = RSB::Admin::Role.create!(
      name: "Dashboard Only #{SecureRandom.hex(4)}",
      permissions: { 'dashboard' => ['index'] }
    )
    admin = RSB::Admin::AdminUser.create!(
      email: "dashonly-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: role
    )

    post rsb_admin.login_path, params: { email: admin.email, password: 'password123' }

    get rsb_admin.roles_path
    assert_response :forbidden
    assert_match 'Go to Dashboard', response.body
  end
end
