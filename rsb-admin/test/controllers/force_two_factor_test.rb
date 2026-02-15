# frozen_string_literal: true

require 'test_helper'

class ForceTwoFactorTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers
  include RSB::Admin::Engine.routes.url_helpers

  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    @admin = create_test_admin!(superadmin: true, email: 'admin@example.com', password: 'password123')
  end

  # --- When require_two_factor is false ---

  test 'admin without 2FA can access dashboard when setting is false' do
    sign_in_admin(@admin, password: 'password123')
    get dashboard_path
    assert_response :success
  end

  # --- When require_two_factor is true ---

  test 'admin without 2FA is redirected to enrollment when setting is true' do
    RSB::Settings.set('admin.require_two_factor', true)
    sign_in_admin(@admin, password: 'password123')

    get dashboard_path
    assert_redirected_to new_profile_two_factor_path
  end

  test 'admin with 2FA can access dashboard when setting is true' do
    RSB::Settings.set('admin.require_two_factor', true)
    @admin.update!(otp_secret: ROTP::Base32.random, otp_required: true)

    sign_in_admin(@admin, password: 'password123')
    # Need to complete 2FA challenge
    totp = ROTP::TOTP.new(@admin.otp_secret)
    post verify_two_factor_login_path, params: { otp_code: totp.now }

    get dashboard_path
    assert_response :success
  end

  test 'force enrollment allows access to two_factor controller' do
    RSB::Settings.set('admin.require_two_factor', true)
    sign_in_admin(@admin, password: 'password123')

    get new_profile_two_factor_path
    assert_response :success # Not redirected
  end

  test 'force enrollment allows logout' do
    RSB::Settings.set('admin.require_two_factor', true)
    sign_in_admin(@admin, password: 'password123')

    delete logout_path
    assert_redirected_to login_path
  end

  test 'force enrollment shows flash message' do
    RSB::Settings.set('admin.require_two_factor', true)
    sign_in_admin(@admin, password: 'password123')

    get dashboard_path
    follow_redirect!
    assert_match(/two-factor/i, flash[:alert].to_s)
  end

  test 'login redirects to enrollment instead of dashboard when force 2FA' do
    RSB::Settings.set('admin.require_two_factor', true)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    # Admin has no 2FA, require_two_factor is true → redirect to enrollment
    assert_redirected_to new_profile_two_factor_path
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
