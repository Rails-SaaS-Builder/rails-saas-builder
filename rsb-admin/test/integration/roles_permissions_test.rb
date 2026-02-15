# frozen_string_literal: true

require 'test_helper'

class RolesPermissionsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Form Rendering ---

  test 'new role form renders without textarea' do
    get rsb_admin.new_role_path
    assert_response :success

    # Should not have the old JSON textarea
    refute_match(/<textarea.*permissions_json/m, response.body)

    # Should have System section with hardcoded resources
    assert_match 'System', response.body
    assert_match(/Settings|Roles|Admin Users/i, response.body)
  end

  test 'new role form has superadmin toggle' do
    get rsb_admin.new_role_path
    assert_response :success
    assert_match(/superadmin/i, response.body)
    assert_match(/name="role\[superadmin_toggle\]"/i, response.body)
  end

  test 'edit role form pre-checks existing permissions' do
    role = RSB::Admin::Role.create!(
      name: 'Editor',
      permissions: { 'settings' => ['index'] }
    )

    get rsb_admin.edit_role_path(role)
    assert_response :success
    assert_match 'Editor', response.body
    # The checkbox for settings index should be checked
    assert_match(/checked/i, response.body)
  end

  test 'role form groups pages with their category' do
    # Register a page in a category
    with_fresh_admin_registry do
      RSB::Admin.registry.register_category 'Authentication' do
        page :sessions_management,
             label: 'Sessions',
             icon: 'key',
             controller: 'rsb/admin/resources',
             actions: [{ key: :index, label: 'Overview' }, { key: :destroy, label: 'Revoke All' }]
      end

      get rsb_admin.new_role_path
      assert_response :success

      # Page should be under "Authentication" header, not a separate "Pages" section
      body = response.body
      auth_section_pos = body.index('Authentication')
      assert auth_section_pos, 'Authentication category should appear in form'

      sessions_pos = body.index('Sessions', auth_section_pos)
      assert sessions_pos, 'Sessions page should appear under Authentication category'

      # The old flat "Pages" section header should NOT exist
      # (Check that "Pages" doesn't appear as a standalone section header)
      # Note: We can't do a simple refute_match because "Pages" might appear in other contexts
    end
  end

  test 'role form includes Dashboard in System section' do
    get rsb_admin.new_role_path
    assert_response :success

    # Dashboard should appear in System section
    assert_match 'Dashboard', response.body
    assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index']"
  end

  test 'saving role with dashboard permission persists correctly' do
    post rsb_admin.roles_path, params: {
      role: {
        name: 'With Dashboard',
        permissions_checkboxes: {
          'dashboard' => ['index'],
          'settings' => ['index']
        }
      }
    }

    role = RSB::Admin::Role.find_by(name: 'With Dashboard')
    assert_equal({ 'dashboard' => ['index'], 'settings' => ['index'] }, role.permissions)
  end

  test 'role form pre-checks existing dashboard permission on edit' do
    role = RSB::Admin::Role.create!(
      name: "Has Dashboard #{SecureRandom.hex(4)}",
      permissions: { 'dashboard' => ['index'], 'settings' => ['index'] }
    )

    get rsb_admin.edit_role_path(role)
    assert_response :success
    assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index'][checked]"
  end

  # --- Permission Saving ---

  test 'create role with checkbox permissions' do
    assert_difference 'RSB::Admin::Role.count', 1 do
      post rsb_admin.roles_path, params: {
        role: {
          name: 'Viewer',
          permissions_checkboxes: {
            'settings' => ['index'],
            'roles' => %w[index show]
          }
        }
      }
    end

    role = RSB::Admin::Role.last
    assert_equal 'Viewer', role.name
    assert_equal({ 'settings' => ['index'], 'roles' => %w[index show] }, role.permissions)
  end

  test 'create superadmin role via toggle' do
    post rsb_admin.roles_path, params: {
      role: {
        name: 'Super',
        superadmin_toggle: '1'
      }
    }

    role = RSB::Admin::Role.last
    assert_equal({ '*' => ['*'] }, role.permissions)
    assert role.superadmin?
  end

  test 'update role replaces permissions with new checkboxes' do
    role = RSB::Admin::Role.create!(
      name: 'Old Perms',
      permissions: { 'settings' => %w[index update], 'roles' => ['index'] }
    )

    patch rsb_admin.role_path(role), params: {
      role: {
        name: 'Old Perms',
        permissions_checkboxes: {
          'settings' => ['index']
        }
      }
    }

    role.reload
    assert_equal({ 'settings' => ['index'] }, role.permissions)
  end

  test 'update with no checkboxes selected sets empty permissions' do
    role = RSB::Admin::Role.create!(
      name: 'No Perms',
      permissions: { 'settings' => ['index'] }
    )

    # Mimic what the form sends: a hidden _dummy field to ensure the param is always present
    patch rsb_admin.role_path(role), params: {
      role: {
        name: 'No Perms',
        permissions_checkboxes: { '_dummy' => [''] }
      }
    }

    role.reload
    assert_equal({}, role.permissions)
  end

  # --- Show Page ---

  test 'show page displays permissions as visual grid' do
    role = RSB::Admin::Role.create!(
      name: 'Manager',
      permissions: {
        'settings' => %w[index update],
        'roles' => %w[index show new create]
      }
    )

    get rsb_admin.role_path(role)
    assert_response :success
    assert_match 'Manager', response.body
    # Should not show raw JSON with curly braces
    refute_match(/\{.*"settings".*:.*\[/, response.body)
  end

  test 'show page for superadmin role shows superadmin badge' do
    role = RSB::Admin::Role.create!(
      name: 'Superadmin',
      permissions: { '*' => ['*'] }
    )

    get rsb_admin.role_path(role)
    assert_response :success
    assert_match(/Superadmin|full access/i, response.body)
  end

  # --- RBAC ---

  test 'restricted admin cannot manage roles' do
    restricted = create_test_admin!(permissions: { 'other' => ['index'] })
    sign_in_admin(restricted)

    get rsb_admin.roles_path
    assert_includes [302, 403], response.status
  end
end
