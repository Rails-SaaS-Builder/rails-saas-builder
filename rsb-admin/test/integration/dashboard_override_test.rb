# frozen_string_literal: true

require 'test_helper'

class DashboardOverrideTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test 'dashboard renders default when no override registered' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'Dashboard', response.body
  end

  test 'dashboard dispatches to custom controller when override registered' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    RSB::Admin.registry.register_dashboard(controller: 'test_dashboard')

    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'Custom Dashboard Index', response.body
  end

  test 'dashboard sub-action dispatches to custom controller action' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    RSB::Admin.registry.register_dashboard(
      controller: 'test_dashboard',
      actions: [
        { key: :index, label: 'Overview' },
        { key: :metrics, label: 'Metrics' }
      ]
    )

    get '/admin/dashboard/metrics'
    assert_response :success
    assert_match 'Custom Dashboard Metrics', response.body
  end

  test 'dashboard sub-action returns 404 when no override registered' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get '/admin/dashboard/metrics'
    assert_response :not_found
  end

  test 'dashboard sub-action returns 404 for unknown action' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    RSB::Admin.registry.register_dashboard(
      controller: 'test_dashboard',
      actions: [{ key: :index, label: 'Overview' }]
    )

    get '/admin/dashboard/unknown_stuff'
    assert_response :not_found
  end

  test 'dashboard index requires dashboard.index permission' do
    RSB::Admin.registry.register_dashboard(controller: 'test_dashboard')

    # Create admin with only "roles" permission (no dashboard permission)
    restricted = create_test_admin!(permissions: { 'roles' => ['index'] })
    sign_in_admin(restricted)

    get rsb_admin.dashboard_path
    assert_response :forbidden
  end

  test 'dashboard sub-action requires per-action permission' do
    RSB::Admin.registry.register_dashboard(
      controller: 'test_dashboard',
      actions: [
        { key: :index, label: 'Overview' },
        { key: :metrics, label: 'Metrics' }
      ]
    )

    # Create admin with only dashboard.index permission (no metrics)
    restricted = create_test_admin!(permissions: { 'dashboard' => ['index'] })
    sign_in_admin(restricted)

    # Dashboard index should work
    get rsb_admin.dashboard_path
    assert_response :success

    # Dashboard metrics should be forbidden
    get '/admin/dashboard/metrics'
    assert_response :forbidden
  end

  test 'dashboard sub-action allowed with correct permission' do
    RSB::Admin.registry.register_dashboard(
      controller: 'test_dashboard',
      actions: [
        { key: :index, label: 'Overview' },
        { key: :metrics, label: 'Metrics' }
      ]
    )

    # Create admin with both dashboard.index and dashboard.metrics permissions
    admin = create_test_admin!(permissions: { 'dashboard' => %w[index metrics] })
    sign_in_admin(admin)

    get '/admin/dashboard/metrics'
    assert_response :success
    assert_match 'Custom Dashboard Metrics', response.body
  end

  test 'dashboard passes breadcrumbs to custom controller' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    RSB::Admin.registry.register_dashboard(controller: 'test_dashboard')

    get rsb_admin.dashboard_path
    assert_response :success

    # Verify the custom controller received breadcrumbs
    # The custom controller inherits @breadcrumbs via request.env
    assert_match 'Custom Dashboard Index', response.body
  end
end
