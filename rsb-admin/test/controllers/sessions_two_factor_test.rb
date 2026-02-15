# frozen_string_literal: true

require 'test_helper'

class SessionsTwoFactorTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers
  include RSB::Admin::Engine.routes.url_helpers

  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    @role = RSB::Admin::Role.create!(
      name: "Super-#{SecureRandom.hex(4)}",
      permissions: { '*' => ['*'] }
    )
    @admin = RSB::Admin::AdminUser.create!(
      email: 'admin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
  end

  # --- Admin WITHOUT 2FA ---

  test 'login without 2FA goes directly to dashboard' do
    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    assert_redirected_to dashboard_path
  end

  # --- Admin WITH 2FA ---

  test 'login with 2FA redirects to challenge page' do
    enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    assert_redirected_to two_factor_login_path
  end

  test '2FA challenge page renders' do
    enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    follow_redirect!
    assert_response :success
    assert_match(/verification/i, response.body)
  end

  test 'valid TOTP code completes login' do
    secret = enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }

    totp = ROTP::TOTP.new(secret)
    post verify_two_factor_login_path, params: { otp_code: totp.now }

    assert_redirected_to dashboard_path
    # Session token should be set
    assert RSB::Admin::AdminSession.where(admin_user: @admin).exists?
  end

  test 'invalid TOTP code re-renders challenge' do
    enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    post verify_two_factor_login_path, params: { otp_code: '000000' }

    assert_response :unprocessable_entity
    assert_match(/invalid/i, response.body)
  end

  test 'valid backup code completes login' do
    enable_2fa(@admin)
    codes = @admin.generate_backup_codes!

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    post verify_two_factor_login_path, params: { otp_code: codes.first }

    assert_redirected_to dashboard_path
  end

  test 'backup code is consumed after use' do
    enable_2fa(@admin)
    codes = @admin.generate_backup_codes!

    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    post verify_two_factor_login_path, params: { otp_code: codes.first }

    # Logout and try same code
    delete logout_path
    post login_path, params: { email: 'admin@example.com', password: 'password123' }
    post verify_two_factor_login_path, params: { otp_code: codes.first }
    assert_response :unprocessable_entity
  end

  test '5 failed attempts locks out and redirects to login' do
    enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }

    5.times do
      post verify_two_factor_login_path, params: { otp_code: '000000' }
    end

    # 6th attempt should redirect to login
    post verify_two_factor_login_path, params: { otp_code: '000000' }
    assert_redirected_to login_path
    follow_redirect!
    assert_match(/too many attempts/i, response.body)
  end

  test 'expired pending session redirects to login' do
    enable_2fa(@admin)

    post login_path, params: { email: 'admin@example.com', password: 'password123' }

    # Simulate time passing (modify session manually is hard in integration tests,
    # so test the controller logic directly or use travel_to)
    travel 6.minutes do
      get two_factor_login_path
      assert_redirected_to login_path
    end
  end

  test 'accessing 2FA page without pending session redirects to login' do
    get two_factor_login_path
    assert_redirected_to login_path
  end

  private

  def enable_2fa(admin)
    secret = ROTP::Base32.random
    admin.update!(otp_secret: secret, otp_required: true)
    admin.generate_backup_codes!
    secret
  end

  def default_url_options
    { host: 'localhost' }
  end
end
