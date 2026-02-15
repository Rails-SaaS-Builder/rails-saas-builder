# frozen_string_literal: true

require 'test_helper'

class AdminTwoFactorTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true, email: "admin-2fa-#{SecureRandom.hex(4)}@test.com",
                                password: 'password123')
  end

  test 'admin login without 2FA goes to dashboard' do
    post '/admin/login', params: { email: @admin.email, password: 'password123' }
    assert_redirected_to '/admin/'
  end

  test 'admin login with 2FA redirects to challenge' do
    secret = ROTP::Base32.random
    @admin.update!(otp_secret: secret, otp_required: true)

    post '/admin/login', params: { email: @admin.email, password: 'password123' }
    assert_redirected_to '/admin/login/two_factor'
  end

  test 'force 2FA redirects unenrolled admin to enrollment' do
    RSB::Settings.set('admin.require_two_factor', true)

    post '/admin/login', params: { email: @admin.email, password: 'password123' }
    assert_redirected_to '/admin/profile/two_factor/new'
  end

  test 'admin with 2FA can complete full login flow' do
    secret = ROTP::Base32.random
    @admin.update!(otp_secret: secret, otp_required: true)
    @admin.generate_backup_codes!

    post '/admin/login', params: { email: @admin.email, password: 'password123' }
    totp = ROTP::TOTP.new(secret)
    post '/admin/login/two_factor', params: { otp_code: totp.now }

    assert_redirected_to '/admin/'
    follow_redirect!
    assert_response :success
  end
end
