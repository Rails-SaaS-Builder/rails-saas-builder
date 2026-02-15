# frozen_string_literal: true

require 'test_helper'

class CredentialConfigTest < ActionDispatch::IntegrationTest
  setup do
    RSB::Settings.reset!
    RSB::Admin.reset!
    RSB::Auth.reset!

    register_all_settings
    register_all_credentials
    register_all_admin_categories

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Per-credential settings registered and accessible ---

  test 'per-credential enabled settings are registered in the auth category' do
    assert_not_nil RSB::Settings.registry.find_definition('auth.credentials.email_password.enabled')
    assert_not_nil RSB::Settings.registry.find_definition('auth.credentials.username_password.enabled')
  end

  test 'per-credential settings default to true' do
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
    assert_equal true, RSB::Settings.get('auth.credentials.username_password.enabled')
  end

  test 'per-credential settings are in Credential Types group' do
    defn = RSB::Settings.registry.find_definition('auth.credentials.email_password.enabled')
    assert_equal 'Credential Types', defn.group
  end

  # --- Admin settings page shows credential type toggles ---

  test 'admin settings auth tab shows Credential Types group' do
    get rsb_admin.settings_path(tab: 'auth')
    assert_response :success
    assert_match 'Credential Types', response.body
    assert_match 'credentials.email_password.enabled', response.body
    assert_match 'credentials.username_password.enabled', response.body
  end

  test 'admin can toggle credential type via batch save' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          "credentials.email_password.enabled": 'true',
          "credentials.username_password.enabled": 'false',
          registration_mode: 'open',
          login_identifier: 'email',
          password_min_length: '8',
          session_duration: '86400',
          max_sessions: '5',
          lockout_threshold: '5',
          lockout_duration: '900',
          verification_required: 'true',
          account_enabled: 'true',
          account_deletion_enabled: 'true',
          "credentials.email_password.verification_required": 'true',
          "credentials.email_password.auto_verify_on_signup": 'false',
          "credentials.email_password.allow_login_unverified": 'false',
          "credentials.email_password.registerable": 'true',
          "credentials.username_password.verification_required": 'true',
          "credentials.username_password.auto_verify_on_signup": 'false',
          "credentials.username_password.allow_login_unverified": 'false',
          "credentials.username_password.registerable": 'true'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')
    assert_equal false, RSB::Settings.get('auth.credentials.username_password.enabled')
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
  end

  # --- Credential registry reflects settings ---

  test 'credential registry enabled query reflects admin-changed settings' do
    RSB::Settings.set('auth.credentials.username_password.enabled', false)

    enabled_keys = RSB::Auth.credentials.enabled_keys
    assert_includes enabled_keys, :email_password
    refute_includes enabled_keys, :username_password
  end

  # --- Login page works with all engines mounted ---

  test 'login page shows credential selector in full app context' do
    get '/auth/session/new'
    assert_response :success
    assert_match 'Email', response.body
  end

  test 'login flow works end-to-end with credential_type' do
    identity = RSB::Auth::Identity.create!
    cred = identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'crossgem@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    cred.update_column(:verified_at, Time.current)

    post '/auth/session', params: {
      identifier: 'crossgem@example.com',
      password: 'password1234',
      credential_type: 'email_password'
    }
    assert_response :redirect
    assert cookies[:rsb_session_token].present?
  end

  # --- Admin identity page still works ---

  test 'admin identities page still renders correctly' do
    RSB::Auth::Identity.create!(status: 'active')
    get '/admin/identities'
    assert_response :success
    assert_match 'Identities', response.body
  end

  # --- ValidationError rescue in batch_update ---

  test 'batch_update rescues ValidationError when disabling last credential type' do
    # Disable username so only email_password remains
    RSB::Settings.set('auth.credentials.username_password.enabled', false)

    # Try to disable the last one via admin batch save
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          "credentials.email_password.enabled": 'false',
          "credentials.username_password.enabled": 'false',
          registration_mode: 'open',
          login_identifier: 'email',
          password_min_length: '8',
          session_duration: '86400',
          max_sessions: '5',
          lockout_threshold: '5',
          lockout_duration: '900',
          verification_required: 'true',
          account_enabled: 'true',
          account_deletion_enabled: 'true',
          "credentials.email_password.verification_required": 'true',
          "credentials.email_password.auto_verify_on_signup": 'false',
          "credentials.email_password.allow_login_unverified": 'false',
          "credentials.email_password.registerable": 'true',
          "credentials.username_password.verification_required": 'true',
          "credentials.username_password.auto_verify_on_signup": 'false',
          "credentials.username_password.allow_login_unverified": 'false',
          "credentials.username_password.registerable": 'true'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')
    follow_redirect!
    assert_match 'at least one credential type must remain enabled', response.body

    # email_password should still be enabled (transaction rolled back)
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
  end

  test 'batch_update rolls back all changes atomically on ValidationError' do
    # Both enabled initially. Try disabling all at once.
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          "credentials.email_password.enabled": 'false',
          "credentials.username_password.enabled": 'false',
          registration_mode: 'open',
          login_identifier: 'email',
          password_min_length: '8',
          session_duration: '86400',
          max_sessions: '5',
          lockout_threshold: '5',
          lockout_duration: '900',
          verification_required: 'true',
          account_enabled: 'true',
          account_deletion_enabled: 'true',
          "credentials.email_password.verification_required": 'true',
          "credentials.email_password.auto_verify_on_signup": 'false',
          "credentials.email_password.allow_login_unverified": 'false',
          "credentials.email_password.registerable": 'true',
          "credentials.username_password.verification_required": 'true',
          "credentials.username_password.auto_verify_on_signup": 'false',
          "credentials.username_password.allow_login_unverified": 'false',
          "credentials.username_password.registerable": 'true'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')

    # Both should still be enabled — the transaction rolled back everything
    assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
    assert_equal true, RSB::Settings.get('auth.credentials.username_password.enabled')
  end

  # --- Existing admin settings flows still work ---

  test 'existing settings batch save still works for non-credential settings' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          registration_mode: 'invite_only',
          login_identifier: 'email',
          password_min_length: '8',
          session_duration: '86400',
          max_sessions: '5',
          lockout_threshold: '5',
          lockout_duration: '900',
          verification_required: 'true',
          account_enabled: 'true',
          account_deletion_enabled: 'true',
          "credentials.email_password.enabled": 'true',
          "credentials.username_password.enabled": 'true',
          "credentials.email_password.verification_required": 'true',
          "credentials.email_password.auto_verify_on_signup": 'false',
          "credentials.email_password.allow_login_unverified": 'false',
          "credentials.email_password.registerable": 'true',
          "credentials.username_password.verification_required": 'true',
          "credentials.username_password.auto_verify_on_signup": 'false',
          "credentials.username_password.allow_login_unverified": 'false',
          "credentials.username_password.registerable": 'true'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')
    assert_equal 'invite_only', RSB::Settings.get('auth.registration_mode')
  end
end
