# frozen_string_literal: true

require 'test_helper'

class RegistrationsRecoveryEmailTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
  end

  test 'username registration passes recovery_email to service' do
    RSB::Settings.set('auth.credentials.username_password.verification_required', false)

    post registration_path, params: {
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      credential_type: 'username_password',
      recovery_email: 'recovery@example.com'
    }

    cred = RSB::Auth::Credential.last
    assert_equal 'recovery@example.com', cred.recovery_email
  end

  test 'registration selector excludes credential types with registerable false' do
    RSB::Settings.set('auth.credentials.username_password.registerable', false)

    get new_registration_path
    assert_response :success

    # Username should not appear in the selector
    refute_match(/username/i, response.body)
    # Email should still appear
    assert_match(/email/i, response.body.downcase)
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
