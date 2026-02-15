# frozen_string_literal: true

require 'test_helper'

class AuthenticationServiceSettingsTest < ActiveSupport::TestCase
  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings

    @identity = create_test_identity
    @credential = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
  end

  test 'verification_required false allows login without verified_at' do
    RSB::Settings.set('auth.credentials.email_password.verification_required', false)

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234'
    )

    assert result.success?
  end

  test 'verification_required true blocks unverified credential' do
    # Default: verification_required is true, credential has no verified_at

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234'
    )

    refute result.success?
    assert_match(/verify/i, result.error)
  end

  test 'verification_required true allows verified credential' do
    @credential.update_columns(verified_at: Time.current)

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234'
    )

    assert result.success?
  end

  test 'allow_login_unverified true lets unverified credential through with flag' do
    RSB::Settings.set('auth.credentials.email_password.allow_login_unverified', true)

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234'
    )

    assert result.success?
    assert_equal true, result.unverified
  end

  test 'verified credential does not set unverified flag' do
    @credential.update_columns(verified_at: Time.current)

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'user@example.com',
      password: 'password1234'
    )

    assert result.success?
    refute result.unverified
  end
end
