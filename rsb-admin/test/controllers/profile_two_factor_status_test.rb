# frozen_string_literal: true

require 'test_helper'

class ProfileTwoFactorStatusTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers
  include RSB::Admin::Engine.routes.url_helpers

  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    @admin = create_test_admin!(superadmin: true, email: 'admin@example.com', password: 'password123')
    sign_in_admin(@admin, password: 'password123')
  end

  test 'profile shows 2FA not set up when disabled' do
    get profile_path
    assert_response :success
    assert_match(/not set up/i, response.body)
    assert_match(/enable/i, response.body.downcase) # Enable button/link
  end

  test 'profile shows 2FA enabled when active' do
    @admin.update!(otp_secret: ROTP::Base32.random, otp_required: true)

    get profile_path
    assert_response :success
    assert_match(/enabled/i, response.body)
    assert_match(/disable/i, response.body.downcase) # Disable button/link
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
