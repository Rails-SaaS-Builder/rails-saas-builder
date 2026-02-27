# frozen_string_literal: true

# Security Test: Admin 2FA Challenge Bypass Prevention
#
# Attack vectors prevented:
# - Skipping 2FA by navigating directly to dashboard after password auth
# - Reusing pending 2FA state after expiry (5 minutes)
# - Exhausting 2FA attempts beyond 5 limit
# - Accessing 2FA endpoint without pending state
#
# Covers: SRS-016 US-014 (2FA Bypass Prevention)

require 'test_helper'

class Admin2faBypassTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories

    # Create admin with 2FA enabled
    @admin = create_test_admin!(superadmin: true)
    secret = ROTP::Base32.random
    @admin.update!(
      otp_secret: secret,
      otp_required: true
    )
    @totp = ROTP::TOTP.new(secret)
  end

  test 'password auth with 2FA enabled redirects to 2FA challenge, not dashboard' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'test-password-secure' }

    # Should redirect to 2FA page, not dashboard
    assert_redirected_to rsb_admin.two_factor_login_path
    follow_redirect!
    assert_response :success
  end

  test 'accessing dashboard without completing 2FA redirects to login' do
    # Authenticate password (creates pending state)
    post rsb_admin.login_path, params: { email: @admin.email, password: 'test-password-secure' }

    # Try to access dashboard directly — should not work
    get rsb_admin.dashboard_path
    # Should redirect to login (not authenticated yet)
    assert_redirected_to rsb_admin.login_path
  end

  test 'pending 2FA state expires after 5 minutes' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'test-password-secure' }

    travel 6.minutes do
      code = @totp.now
      post rsb_admin.verify_two_factor_login_path, params: { otp_code: code }
      # Should be rejected — pending state expired
      assert_redirected_to rsb_admin.login_path
    end
  end

  test 'pending 2FA state is cleared after successful verification' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'test-password-secure' }

    code = @totp.now
    post rsb_admin.verify_two_factor_login_path, params: { otp_code: code }
    assert_redirected_to rsb_admin.dashboard_path

    # Verify admin is now authenticated
    follow_redirect!
    assert_response :success
  end

  test '5 failed 2FA attempts invalidates pending state' do
    post rsb_admin.login_path, params: { email: @admin.email, password: 'test-password-secure' }

    # Fail 5 times
    5.times do
      post rsb_admin.verify_two_factor_login_path, params: { otp_code: '000000' }
    end

    # 6th attempt should redirect to login (pending cleared after 5 failures)
    post rsb_admin.verify_two_factor_login_path, params: { otp_code: @totp.now }
    assert_redirected_to rsb_admin.login_path
  end

  test 'accessing verify_two_factor without pending state redirects to login' do
    # No password authentication first
    post rsb_admin.verify_two_factor_login_path, params: { otp_code: '123456' }
    assert_redirected_to rsb_admin.login_path
  end

  test 'require_two_factor setting forces 2FA enrollment for non-enrolled admins' do
    with_settings('admin.require_two_factor' => true) do
      # Create admin WITHOUT 2FA
      unenrolled_admin = create_test_admin!(superadmin: true)
      sign_in_admin(unenrolled_admin)

      # sign_in redirects to dashboard, then dashboard check re-redirects to 2FA enrollment
      # Follow initial login redirect first
      assert_redirected_to rsb_admin.new_profile_two_factor_path
    end
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
