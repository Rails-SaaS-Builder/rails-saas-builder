# frozen_string_literal: true

require 'test_helper'

class SettingsPageRedesignTest < ActionDispatch::IntegrationTest
  setup do
    RSB::Settings.reset!
    RSB::Admin.reset!

    register_all_settings

    role = RSB::Admin::Role.create!(
      name: "settings_regression_#{SecureRandom.hex(4)}",
      permissions: { '*' => ['*'] }
    )
    @admin = RSB::Admin::AdminUser.create!(
      email: "regression-#{SecureRandom.hex(4)}@example.com",
      password: 'test-password-secure',
      password_confirmation: 'test-password-secure',
      role: role
    )
    sign_in_admin(@admin)
  end

  # --- Tab rendering with all gems ---

  test 'settings page renders tabs for auth, entitlements, and admin categories' do
    get rsb_admin.settings_path
    assert_response :success

    assert_match 'Auth', response.body
    assert_match 'Entitlements', response.body
    assert_match 'Admin', response.body
  end

  test 'auth tab shows correct subgroups' do
    get rsb_admin.settings_path(tab: 'auth')
    assert_response :success

    assert_match 'Registration', response.body
    assert_match 'Session &amp; Security', response.body
    assert_match 'Features', response.body
  end

  test 'admin tab shows correct subgroups' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success

    assert_match 'General', response.body
    assert_match 'Branding', response.body
  end

  test 'entitlements tab shows correct subgroups' do
    get rsb_admin.settings_path(tab: 'entitlements')
    assert_response :success

    assert_match 'General', response.body
  end

  # --- Grouped definitions via registry ---

  test 'grouped_definitions returns correct groups for auth' do
    groups = RSB::Settings.registry.grouped_definitions('auth')

    assert groups.key?('Registration'), "Expected 'Registration' group"
    assert groups.key?('Session & Security'), "Expected 'Session & Security' group"
    assert groups.key?('Features'), "Expected 'Features' group"

    reg_keys = groups['Registration'].map(&:key)
    assert_includes reg_keys, :registration_mode
    assert_includes reg_keys, :login_identifier
    assert_includes reg_keys, :password_min_length
    assert_includes reg_keys, :verification_required

    sec_keys = groups['Session & Security'].map(&:key)
    assert_includes sec_keys, :session_duration
    assert_includes sec_keys, :max_sessions
    assert_includes sec_keys, :lockout_threshold
    assert_includes sec_keys, :lockout_duration

    feat_keys = groups['Features'].map(&:key)
    assert_includes feat_keys, :account_enabled
    assert_includes feat_keys, :account_deletion_enabled
  end

  test 'grouped_definitions returns correct groups for admin' do
    groups = RSB::Settings.registry.grouped_definitions('admin')

    assert groups.key?('General'), "Expected 'General' group"
    assert groups.key?('Branding'), "Expected 'Branding' group"

    general_keys = groups['General'].map(&:key)
    assert_includes general_keys, :enabled
    assert_includes general_keys, :theme
    assert_includes general_keys, :per_page

    branding_keys = groups['Branding'].map(&:key)
    assert_includes branding_keys, :app_name
    assert_includes branding_keys, :company_name
    assert_includes branding_keys, :logo_url
    assert_includes branding_keys, :footer_text
  end

  # --- depends_on across the full stack ---

  test 'account_deletion_enabled depends_on account_enabled' do
    defn = RSB::Settings.registry.find_definition('auth.account_deletion_enabled')
    assert_equal 'auth.account_enabled', defn.depends_on
  end

  test 'depends_on disables field when parent is off (auth tab)' do
    RSB::Settings.set('auth.account_enabled', false)

    get rsb_admin.settings_path(tab: 'auth')
    assert_response :success

    # account_deletion_enabled should be disabled
    assert_match(/disabled.*account_deletion_enabled|account_deletion_enabled.*disabled/mi, response.body)
    # Should show the "disabled because" hint
    assert_match(/Disabled because/i, response.body)
  end

  test 'depends_on enables field when parent is on' do
    RSB::Settings.set('auth.account_enabled', true)

    get rsb_admin.settings_path(tab: 'auth')
    assert_response :success

    # account_deletion_enabled should NOT show the amber hint
    refute_match(/account_deletion_enabled.*Disabled because/mi, response.body)
  end

  # --- Batch save end-to-end ---

  test 'batch save persists changed auth settings and redirects with tab' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          registration_mode: 'invite_only',
          session_duration: '7200',
          max_sessions: '10',
          password_min_length: '8',
          lockout_threshold: '5',
          lockout_duration: '900',
          verification_required: 'true',
          account_enabled: 'true',
          account_deletion_enabled: 'true',
          login_identifier: 'email'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')
    assert_equal 'invite_only', RSB::Settings.get('auth.registration_mode')
    assert_equal 7200, RSB::Settings.get('auth.session_duration')
    assert_equal 10, RSB::Settings.get('auth.max_sessions')
  end

  test 'batch save skips depends_on disabled settings' do
    RSB::Settings.set('auth.account_enabled', false)

    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'auth',
        tab: 'auth',
        values: {
          account_enabled: 'false',
          account_deletion_enabled: 'false'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'auth')
    # account_deletion_enabled should NOT be changed (parent is false)
    assert_equal true, RSB::Settings.get('auth.account_deletion_enabled')
  end

  # --- Tab persistence ---

  test 'tab persistence survives save redirect' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'admin',
        tab: 'admin',
        values: { per_page: '50' }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'admin')
    follow_redirect!
    assert_response :success
    assert_match 'Admin', response.body
  end

  # --- Backward compat ---

  test 'old single-setting update route still works' do
    patch rsb_admin.setting_path(category: 'admin', key: 'per_page'), params: { value: '30' }
    assert_redirected_to rsb_admin.settings_path
    assert_equal 30, RSB::Settings.get('admin.per_page')
  end
end
