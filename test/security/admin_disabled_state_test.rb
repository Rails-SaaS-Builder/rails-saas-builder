# frozen_string_literal: true

# Security Test: Admin Panel Disabled State Enforcement
#
# Attack vectors prevented:
# - Accessing admin panel when admin.enabled=false
# - Bypassing ENV-based disable via DB setting change
# - Any admin route accessible when panel is disabled
#
# Covers: SRS-016 US-017 (Admin Disabled State)

require 'test_helper'

class AdminDisabledStateTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
  end

  teardown do
    # Re-enable admin panel after tests
    RSB::Settings.set('admin.enabled', true)
  end

  test 'disabled admin panel returns 503 for login page' do
    RSB::Settings.set('admin.enabled', false)

    get rsb_admin.login_path
    assert_response :service_unavailable
  end

  test 'disabled admin panel returns 503 for dashboard' do
    sign_in_admin(@admin)
    RSB::Settings.set('admin.enabled', false)

    get rsb_admin.dashboard_path
    assert_response :service_unavailable
  end

  test 'disabled admin panel returns 503 for settings' do
    sign_in_admin(@admin)
    RSB::Settings.set('admin.enabled', false)

    get rsb_admin.settings_path
    assert_response :service_unavailable
  end

  test 'disabled admin panel returns 503 for logout' do
    sign_in_admin(@admin)
    RSB::Settings.set('admin.enabled', false)

    delete rsb_admin.logout_path
    assert_response :service_unavailable
  end

  test 'disabled check is first before_action — cannot be bypassed' do
    RSB::Settings.set('admin.enabled', false)

    # Even trying to access various routes should all get 503
    get rsb_admin.login_path
    assert_response :service_unavailable

    get rsb_admin.dashboard_path
    assert_response :service_unavailable

    get rsb_admin.settings_path
    assert_response :service_unavailable

    get rsb_admin.profile_path
    assert_response :service_unavailable
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
