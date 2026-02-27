# frozen_string_literal: true

# Security Test: Admin RBAC Enforcement Completeness
#
# Attack vectors prevented:
# - Unauthorized access to admin resources
# - RBAC bypass by crafting URLs directly
# - No-role admin accessing restricted resources
# - Read-only admin performing write operations
#
# Covers: SRS-016 US-013 (RBAC Enforcement)

require 'test_helper'

class AdminRbacTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
  end

  # --- No-role admin ---

  test 'admin with no role can only get forbidden page' do
    no_role_admin = create_test_admin!(no_role: true)
    sign_in_admin(no_role_admin)

    # Dashboard should be forbidden
    get rsb_admin.dashboard_path
    assert_admin_forbidden_page
  end

  test 'admin with no role cannot access any resource by URL crafting' do
    no_role_admin = create_test_admin!(no_role: true)
    sign_in_admin(no_role_admin)

    # Try to access identity resource
    get '/admin/identities'
    assert_admin_forbidden_page
  end

  # --- Limited role admin ---

  test 'read-only admin cannot perform write operations via POST' do
    read_only_admin = create_test_admin!(permissions: {
      'dashboard' => ['index'],
      'identities' => %w[index show]
    })
    sign_in_admin(read_only_admin)

    # Can view dashboard
    get rsb_admin.dashboard_path
    assert_response :success

    # Cannot create resources (POST)
    post '/admin/identities', params: {}
    assert_admin_forbidden_page
  end

  test 'limited admin cannot access resources outside their permissions' do
    limited_admin = create_test_admin!(permissions: {
      'dashboard' => ['index']
    })
    sign_in_admin(limited_admin)

    # Dashboard works
    get rsb_admin.dashboard_path
    assert_response :success

    # Settings should be forbidden
    get rsb_admin.settings_path
    assert_admin_forbidden_page

    # Admin users should be forbidden
    get rsb_admin.admin_users_path
    assert_admin_forbidden_page
  end

  # --- Superadmin ---

  test 'superadmin can access all resources' do
    superadmin = create_test_admin!(superadmin: true)
    sign_in_admin(superadmin)

    get rsb_admin.dashboard_path
    assert_response :success

    get rsb_admin.settings_path
    assert_response :success

    get rsb_admin.admin_users_path
    assert_response :success
  end

  # --- Authorization returns 403, not redirect ---

  test 'authorize_admin_action! renders forbidden page (not redirect)' do
    no_role_admin = create_test_admin!(no_role: true)
    sign_in_admin(no_role_admin)

    get rsb_admin.dashboard_path
    # Should render the forbidden page in-place (403)
    # Not a 302 redirect
    assert_admin_forbidden_page
  end

  # --- Settings controller authorization ---

  test 'settings update requires write permissions' do
    read_only_admin = create_test_admin!(permissions: {
      'settings' => ['index']
    })
    sign_in_admin(read_only_admin)

    # Can view settings
    get rsb_admin.settings_path
    assert_response :success

    # Cannot update settings
    patch rsb_admin.settings_path, params: { category: 'admin', settings: { app_name: 'Hacked' } }
    assert_admin_forbidden_page
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
