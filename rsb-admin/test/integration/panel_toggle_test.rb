# frozen_string_literal: true

require 'test_helper'

class PanelToggleTest < ActionDispatch::IntegrationTest
  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
  end

  teardown do
    ENV.delete('RSB_ADMIN_ENABLED')
  end

  # --- Panel enabled (default) ---

  test 'dashboard is accessible when panel is enabled' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    get rsb_admin.dashboard_path
    assert_response :success
  end

  test 'login page is accessible when panel is enabled' do
    get rsb_admin.login_path
    assert_response :success
  end

  # --- Panel disabled via ENV ---

  test 'dashboard returns 503 when panel is disabled via ENV' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    get rsb_admin.dashboard_path
    assert_response :service_unavailable
  end

  test 'login page returns 503 when panel is disabled via ENV' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    get rsb_admin.login_path
    assert_response :service_unavailable
  end

  test 'logout returns 503 when panel is disabled via ENV' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    delete rsb_admin.logout_path
    assert_response :service_unavailable
  end

  test 'settings page returns 503 when panel is disabled via ENV' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
    get rsb_admin.settings_path
    assert_response :service_unavailable
  end

  # --- Disabled page content ---

  test 'disabled page renders standalone HTML without admin layout' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    get rsb_admin.login_path
    assert_response :service_unavailable
    # Standalone page — no sidebar, no header
    assert_no_match 'sidebar', response.body.downcase
    # Contains the disabled message
    assert_match I18n.t('rsb.admin.shared.panel_disabled'), response.body
    assert_match I18n.t('rsb.admin.shared.panel_disabled_message'), response.body
  end

  test 'disabled page shows app name in title' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    get rsb_admin.login_path
    assert_response :service_unavailable
    assert_match RSB::Admin.configuration.app_name, response.body
  end

  # --- ENV override priority ---

  test 'ENV true overrides DB false' do
    RSB::Settings.set('admin.enabled', 'false')
    ENV['RSB_ADMIN_ENABLED'] = 'true'

    get rsb_admin.login_path
    assert_response :success
  end

  test 'ENV false overrides DB true' do
    RSB::Settings.set('admin.enabled', 'true')
    ENV['RSB_ADMIN_ENABLED'] = 'false'

    get rsb_admin.login_path
    assert_response :service_unavailable
  end

  # --- Panel disabled via DB ---

  test 'all routes return 503 when disabled via DB setting' do
    RSB::Settings.set('admin.enabled', 'false')

    get rsb_admin.login_path
    assert_response :service_unavailable

    get rsb_admin.dashboard_path
    assert_response :service_unavailable
  end

  # --- Re-enabling ---

  test 'panel becomes accessible again after re-enabling via ENV' do
    ENV['RSB_ADMIN_ENABLED'] = 'false'
    get rsb_admin.login_path
    assert_response :service_unavailable

    ENV['RSB_ADMIN_ENABLED'] = 'true'
    get rsb_admin.login_path
    assert_response :success
  end
end
