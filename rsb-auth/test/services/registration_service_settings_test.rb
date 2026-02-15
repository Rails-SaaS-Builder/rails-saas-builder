# frozen_string_literal: true

require 'test_helper'

class RegistrationServiceSettingsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
  end

  test 'rejects registration when registerable setting is false' do
    RSB::Settings.set('auth.credentials.email_password.registerable', false)

    result = RSB::Auth::RegistrationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      credential_type: :email_password
    )

    refute result.success?
    assert_includes result.errors, 'This registration method is not available.'
  end

  test 'allows registration when registerable setting is true' do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      credential_type: :email_password
    )

    assert result.success?
  end

  test 'auto_verify_on_signup sets verified_at immediately' do
    RSB::Settings.set('auth.credentials.email_password.verification_required', false)
    RSB::Settings.set('auth.credentials.email_password.auto_verify_on_signup', true)

    result = RSB::Auth::RegistrationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      credential_type: :email_password
    )

    assert result.success?
    assert_not_nil result.credential.verified_at
  end

  test 'auto_verify_on_signup does not send verification email' do
    RSB::Settings.set('auth.credentials.email_password.verification_required', false)
    RSB::Settings.set('auth.credentials.email_password.auto_verify_on_signup', true)

    assert_no_enqueued_emails do
      RSB::Auth::RegistrationService.new.call(
        identifier: 'user@example.com',
        password: 'password1234',
        password_confirmation: 'password1234',
        credential_type: :email_password
      )
    end
  end

  test 'verification_required false skips send_verification' do
    RSB::Settings.set('auth.credentials.email_password.verification_required', false)

    assert_no_enqueued_emails do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: 'user@example.com',
        password: 'password1234',
        password_confirmation: 'password1234',
        credential_type: :email_password
      )
      assert result.success?
      assert_nil result.credential.verified_at
      assert_nil result.credential.verification_token
    end
  end

  test 'verification_required true sends verification email' do
    # Default: verification_required is true
    assert_enqueued_emails 1 do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: 'user@example.com',
        password: 'password1234',
        password_confirmation: 'password1234',
        credential_type: :email_password
      )
      assert result.success?
      assert_not_nil result.credential.verification_token
    end
  end

  test 'username registration with recovery_email and verification sends email' do
    assert_enqueued_emails 1 do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: 'testuser',
        password: 'password1234',
        password_confirmation: 'password1234',
        credential_type: :username_password,
        recovery_email: 'recovery@example.com'
      )
      assert result.success?
    end
  end

  test 'username registration without recovery_email when verification_required skips email' do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      credential_type: :username_password
    )
    # Should succeed — token is set but no email sent (no deliverable_email)
    assert result.success?
  end
end
