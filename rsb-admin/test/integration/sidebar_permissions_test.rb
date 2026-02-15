# frozen_string_literal: true

require 'test_helper'

class SidebarPermissionsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Admin.registry.register_category 'Authentication' do
      resource RSB::Admin::AdminUser,
               actions: %i[index show],
               label: 'Test Users',
               icon: 'users'
    end
  end

  test 'superadmin sees all sidebar items as active links' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']"
    assert_select "nav a[href='#{rsb_admin.admin_users_path}']"
    assert_select "nav a[href='#{rsb_admin.roles_path}']"
    assert_select "nav a[href='#{rsb_admin.settings_path}']"
    assert_select 'nav span.cursor-not-allowed', count: 0
  end

  test 'restricted admin sees unpermitted items as disabled spans' do
    admin = create_test_admin!(permissions: { 'dashboard' => ['index'], 'settings' => ['index'] })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    # Dashboard should be a link (permitted)
    assert_select "nav a[href='#{rsb_admin.dashboard_path}']"

    # Settings should be a link (permitted)
    assert_select "nav a[href='#{rsb_admin.settings_path}']"

    # Admin Users and Roles should be disabled spans (no permission but System section is visible)
    assert_select "nav span[title='No access']", minimum: 2
  end

  test 'no-role admin sees all items as disabled' do
    admin = RSB::Admin::AdminUser.create!(
      email: 'norole-sidebar@example.com',
      password: 'password-secure-123',
      password_confirmation: 'password-secure-123'
    )
    post rsb_admin.login_path, params: { email: admin.email, password: 'password-secure-123' }

    # Will get forbidden page but sidebar still renders in layout
    get rsb_admin.dashboard_path
    assert_response :forbidden

    # Dashboard should be disabled (no permission) - shown as disabled span in sidebar
    # Note: Breadcrumb root still links to dashboard (by design), but sidebar item is disabled
    assert_select "nav span[title='No access']", text: /Dashboard/, minimum: 1
  end

  test 'category header is hidden when no items in category are permitted' do
    admin = create_test_admin!(permissions: { 'dashboard' => ['index'], 'settings' => ['index'] })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    # "Authentication" category should be hidden (admin has no permission for Test Users)
    refute_match %r{<div[^>]*>Authentication</div>}, response.body
  end

  test 'category header is visible when at least one item is permitted' do
    admin = create_test_admin!(permissions: { 'dashboard' => ['index'], 'admin_users' => ['index'] })
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success

    # "System" header should be visible
    assert_match 'System', response.body
  end
end
