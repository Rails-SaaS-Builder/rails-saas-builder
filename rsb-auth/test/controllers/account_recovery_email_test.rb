# frozen_string_literal: true

require 'test_helper'

class AccountRecoveryEmailTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
    RSB::Settings.set('auth.credentials.username_password.enabled', true)
    RSB::Settings.set('auth.credentials.username_password.authenticatable', true)
  end

  test 'login_methods show displays recovery_email for username credential' do
    identity = create_test_identity
    cred = identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'recovery@example.com',
      verified_at: Time.current
    )
    post session_path, params: { identifier: 'testuser', password: 'password1234' }

    get account_login_method_path(cred)
    assert_response :success
    assert_match(/recovery@example.com/, response.body)
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
