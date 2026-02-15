# frozen_string_literal: true

require 'test_helper'

class AdminIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'auth resources are registered in admin' do
    registry = RSB::Admin.registry

    assert registry.category?('Authentication'),
           'Authentication category should be registered by rsb-auth'

    identity_reg = registry.find_resource(RSB::Auth::Identity)
    assert identity_reg, 'Identity should be registered in admin'
    assert_equal 'Authentication', identity_reg.category_name

    invitation_reg = registry.find_resource(RSB::Auth::Invitation)
    assert invitation_reg, 'Invitation should be registered in admin'
  end

  test 'entitlement resources are registered in admin' do
    registry = RSB::Admin.registry

    assert registry.category?('Billing'),
           'Billing category should be registered by rsb-entitlements'

    plan_reg = registry.find_resource(RSB::Entitlements::Plan)
    assert plan_reg, 'Plan should be registered in admin'
    assert_equal 'Billing', plan_reg.category_name
  end

  test 'admin dashboard renders with all categories' do
    get rsb_admin.dashboard_path
    assert_response :success
  end

  test 'admin settings page shows settings from all gems' do
    get rsb_admin.settings_path
    assert_response :success

    # Verify categories from all gems appear
    assert_match(/auth/i, response.body)
    assert_match(/entitlements/i, response.body)
    assert_match(/admin/i, response.body)
  end

  test 'admin can update a setting from another gem' do
    patch rsb_admin.setting_path(category: 'auth', key: 'registration_mode'),
          params: { value: 'invite_only' }

    assert_redirected_to rsb_admin.settings_path
    assert_equal 'invite_only', RSB::Settings.get('auth.registration_mode')
  end

  test 'locked setting cannot be updated via admin' do
    RSB::Settings.configure do |config|
      config.lock 'auth.registration_mode'
    end

    patch rsb_admin.setting_path(category: 'auth', key: 'registration_mode'),
          params: { value: 'disabled' }

    assert_redirected_to rsb_admin.settings_path
    assert_not_equal 'disabled', RSB::Settings.get('auth.registration_mode')
  end

  test 'GET /admin/identities renders index for registered auth resource' do
    RSB::Auth::Identity.create!(status: 'active')
    get '/admin/identities'
    assert_response :success
    assert_match 'Identities', response.body
  end

  test 'GET /admin/identities/:id renders show for registered auth resource' do
    identity = RSB::Auth::Identity.create!(status: 'active')
    get "/admin/identities/#{identity.id}"
    assert_response :success
  end

  test 'GET /admin/plans renders index for registered entitlements resource' do
    RSB::Entitlements::Plan.create!(
      name: 'Test', slug: "test-#{SecureRandom.hex(4)}",
      interval: 'monthly', price_cents: 0, currency: 'usd'
    )
    get '/admin/plans'
    assert_response :success
    assert_match 'Plans', response.body
  end

  test 'GET /admin/nonexistent_resource returns 404' do
    get '/admin/nonexistent_resource'
    assert_response :not_found
  end

  test 'admin with no permissions is denied access to registered resource' do
    restricted_admin = create_test_admin!(permissions: {})
    sign_in_admin(restricted_admin)
    get '/admin/identities'
    assert_admin_denied
  end

  test 'GET /admin/sessions_management renders page for registered auth page' do
    get '/admin/sessions_management'
    assert_response :success
    assert_match 'Active Sessions', response.body
  end

  test 'GET /admin/usage_counters renders page for registered entitlements page' do
    get '/admin/usage_counters'
    assert_response :success
    assert_match 'Usage Monitoring', response.body
  end

  test 'index page shows New button for resource with :new action' do
    get '/admin/invitations'
    assert_response :success
    assert_match 'New', response.body
  end

  test 'index page does NOT show New button for resource without :new action' do
    get '/admin/identities'
    assert_response :success
    assert_no_match(/btn.*New/, response.body)
  end

  test 'GET /admin/invitations/new renders new form' do
    get '/admin/invitations/new'
    assert_response :success
    assert_select 'form'
  end

  test 'GET /admin/plans/new renders new form' do
    get '/admin/plans/new'
    assert_response :success
    assert_select 'form'
  end
end
