# frozen_string_literal: true

require 'test_helper'

class DashboardRbacTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Form Rendering ---

  test 'role form shows only index checkbox when no dashboard override' do
    get rsb_admin.new_role_path
    assert_response :success
    assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index']"
    assert_select "input[name='role[permissions_checkboxes][dashboard][]']", count: 1
  end

  test 'role form shows dashboard action checkboxes when override with actions registered' do
    with_fresh_admin_registry do
      RSB::Admin.registry.register_dashboard(
        controller: 'test_dashboard',
        actions: [
          { key: :index, label: 'Overview' },
          { key: :metrics, label: 'Metrics' }
        ]
      )

      get rsb_admin.new_role_path
      assert_response :success
      assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index']"
      assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='metrics']"
      assert_select "input[name='role[permissions_checkboxes][dashboard][]']", count: 2
    end
  end

  test 'role form shows only index when override registered without actions' do
    with_fresh_admin_registry do
      RSB::Admin.registry.register_dashboard(controller: 'test_dashboard')

      get rsb_admin.new_role_path
      assert_response :success
      assert_select "input[name='role[permissions_checkboxes][dashboard][]']", count: 1
      assert_select "input[name='role[permissions_checkboxes][dashboard][]'][value='index']"
    end
  end

  # --- Persistence ---

  test 'saving role with dashboard action permissions persists correctly' do
    with_fresh_admin_registry do
      RSB::Admin.registry.register_dashboard(
        controller: 'test_dashboard',
        actions: [
          { key: :index, label: 'Overview' },
          { key: :metrics, label: 'Metrics' }
        ]
      )

      post rsb_admin.roles_path, params: {
        role: {
          name: "Dashboard Multi #{SecureRandom.hex(4)}",
          permissions_checkboxes: {
            'dashboard' => %w[index metrics]
          }
        }
      }

      role = RSB::Admin::Role.last
      assert_equal %w[index metrics], role.permissions['dashboard']
    end
  end

  test 'saving role with partial dashboard permissions persists only selected' do
    with_fresh_admin_registry do
      RSB::Admin.registry.register_dashboard(
        controller: 'test_dashboard',
        actions: [
          { key: :index, label: 'Overview' },
          { key: :metrics, label: 'Metrics' }
        ]
      )

      post rsb_admin.roles_path, params: {
        role: {
          name: "Dashboard Partial #{SecureRandom.hex(4)}",
          permissions_checkboxes: {
            'dashboard' => ['index']
          }
        }
      }

      role = RSB::Admin::Role.last
      assert_equal ['index'], role.permissions['dashboard']
    end
  end
end
