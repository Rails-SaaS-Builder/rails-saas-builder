# frozen_string_literal: true

require 'test_helper'

class PhoneUnregistrationTest < ActiveSupport::TestCase
  setup do
    register_auth_settings
    register_all_auth_credentials
  end

  test 'phone_password is not in the credential registry' do
    assert_nil RSB::Auth.credentials.find(:phone_password)
  end

  test 'phone_password is not in enabled keys' do
    refute_includes RSB::Auth.credentials.enabled.map(&:key), :phone_password
  end

  test 'email_password is still registered' do
    assert RSB::Auth.credentials.find(:email_password)
  end

  test 'username_password is still registered' do
    assert RSB::Auth.credentials.find(:username_password)
  end

  test 'register_all_auth_credentials does not include phone' do
    RSB::Auth.reset!
    register_auth_settings
    register_all_auth_credentials
    assert_nil RSB::Auth.credentials.find(:phone_password)
  end

  test 'no auth.credentials.phone_password.enabled setting is registered' do
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
    # When a setting is not registered, get() returns nil (the default from a nil definition)
    assert_nil RSB::Settings.get('auth.credentials.phone_password.enabled')
  end

  test 'PhonePassword model class still exists' do
    assert defined?(RSB::Auth::Credential::PhonePassword)
  end
end
