# frozen_string_literal: true

require 'test_helper'

class CredentialSettingsRegistrarExtendedTest < ActiveSupport::TestCase
  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
  end

  # --- Settings existence ---

  test 'registers verification_required setting for email_password' do
    value = RSB::Settings.get('auth.credentials.email_password.verification_required')
    assert_equal true, value # default
  end

  test 'registers auto_verify_on_signup setting for email_password' do
    value = RSB::Settings.get('auth.credentials.email_password.auto_verify_on_signup')
    assert_equal false, value # default
  end

  test 'registers allow_login_unverified setting for email_password' do
    value = RSB::Settings.get('auth.credentials.email_password.allow_login_unverified')
    assert_equal false, value # default
  end

  test 'registers registerable setting for email_password' do
    value = RSB::Settings.get('auth.credentials.email_password.registerable')
    assert_equal true, value # default
  end

  test 'registers all 4 new settings for username_password' do
    assert_equal true, RSB::Settings.get('auth.credentials.username_password.verification_required')
    assert_equal false, RSB::Settings.get('auth.credentials.username_password.auto_verify_on_signup')
    assert_equal false, RSB::Settings.get('auth.credentials.username_password.allow_login_unverified')
    assert_equal true, RSB::Settings.get('auth.credentials.username_password.registerable')
  end

  test 'no settings registered for phone_password (unregistered type)' do
    # When a setting is not registered, get() returns nil
    assert_nil RSB::Settings.get('auth.credentials.phone_password.verification_required')
  end

  # --- depends_on wiring ---

  test 'verification_required depends on enabled' do
    schema_entry = RSB::Settings.registry.find_definition('auth.credentials.email_password.verification_required')
    assert_equal 'auth.credentials.email_password.enabled', schema_entry.depends_on
  end

  test 'auto_verify_on_signup depends on enabled' do
    schema_entry = RSB::Settings.registry.find_definition('auth.credentials.email_password.auto_verify_on_signup')
    assert_equal 'auth.credentials.email_password.enabled', schema_entry.depends_on
  end

  test 'allow_login_unverified depends on enabled' do
    schema_entry = RSB::Settings.registry.find_definition('auth.credentials.email_password.allow_login_unverified')
    assert_equal 'auth.credentials.email_password.enabled', schema_entry.depends_on
  end

  test 'registerable depends on enabled' do
    schema_entry = RSB::Settings.registry.find_definition('auth.credentials.email_password.registerable')
    assert_equal 'auth.credentials.email_password.enabled', schema_entry.depends_on
  end

  # --- Mutual exclusion validation ---

  test 'cannot enable auto_verify_on_signup when verification_required is true' do
    RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation

    assert_raises(RSB::Settings::ValidationError) do
      RSB::Settings.set('auth.credentials.email_password.auto_verify_on_signup', true)
    end
  end

  test 'can enable auto_verify_on_signup when verification_required is false' do
    RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation

    RSB::Settings.set('auth.credentials.email_password.verification_required', false)
    RSB::Settings.set('auth.credentials.email_password.auto_verify_on_signup', true)
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.auto_verify_on_signup')
  end

  test 'cannot enable verification_required when auto_verify_on_signup is true' do
    RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation

    RSB::Settings.set('auth.credentials.email_password.verification_required', false)
    RSB::Settings.set('auth.credentials.email_password.auto_verify_on_signup', true)

    assert_raises(RSB::Settings::ValidationError) do
      RSB::Settings.set('auth.credentials.email_password.verification_required', true)
    end
  end

  # --- Enabled setting still works ---

  test 'enabled setting still exists for each credential type' do
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
    assert_equal true, RSB::Settings.get('auth.credentials.username_password.enabled')
  end

  test 'last type validation still prevents disabling all types' do
    RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation

    # Disable username first
    RSB::Settings.set('auth.credentials.username_password.enabled', false)

    # Cannot disable the last one (email)
    assert_raises(RSB::Settings::ValidationError) do
      RSB::Settings.set('auth.credentials.email_password.enabled', false)
    end
  end
end
