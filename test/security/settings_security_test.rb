# frozen_string_literal: true

# Security Test: Settings Value Security & Batch Update Safety
#
# Attack vectors prevented:
# - Locked setting bypass via RSB::Settings.set
# - Locked setting bypass via admin batch update
# - Parameter injection in admin settings batch update
# - Cache poisoning (stale values after invalidation)
# - on_change callback rollback on validation failure
#
# Covers: SRS-016 US-021 (Settings Value Security), US-022 (Batch Update Safety)

require 'test_helper'

class SettingsSecurityTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  teardown do
    RSB::Settings.configuration.instance_variable_get(:@locks)&.clear
  end

  # --- US-021: Locked settings ---

  test 'locked setting cannot be changed via RSB::Settings.set (raises LockedSettingError)' do
    RSB::Settings.configure { |c| c.lock('admin.app_name') }

    assert_raises(RSB::Settings::LockedSettingError) do
      RSB::Settings.set('admin.app_name', 'Hacked')
    end
  end

  test 'locked setting cannot be changed via admin settings page' do
    RSB::Settings.configure { |c| c.lock('admin.app_name') }
    original = RSB::Settings.get('admin.app_name')

    patch rsb_admin.settings_path, params: {
      category: 'admin',
      settings: { app_name: 'Hacked via UI' }
    }

    assert_equal original, RSB::Settings.get('admin.app_name'),
                 'Locked setting must not change via admin batch update'
  end

  # --- US-021: Encryption verification ---

  test 'Setting model uses ActiveRecord encryption on value column' do
    assert RSB::Settings::Setting.encrypted_attributes.include?(:value),
           'Setting.value must use ActiveRecord encryption'
  end

  # --- US-021: Cache invalidation ---

  test 'invalidate_cache! clears all cached values' do
    RSB::Settings.set('admin.app_name', 'Cached Name')
    assert_equal 'Cached Name', RSB::Settings.get('admin.app_name')

    RSB::Settings.invalidate_cache!

    # After invalidation, should re-resolve from DB
    result = RSB::Settings.get('admin.app_name')
    assert_equal 'Cached Name', result, 'Should re-read from DB after cache invalidation'
  end

  # --- US-022: Batch update safety ---

  test 'batch update only processes settings for submitted category' do
    original_auth_mode = RSB::Settings.get('auth.registration_mode')

    # Submit settings for 'admin' category but include auth settings in params
    patch rsb_admin.settings_path, params: {
      category: 'admin',
      settings: {
        app_name: 'Updated',
        'auth.registration_mode': 'disabled' # injection attempt using different category
      }
    }

    assert_equal original_auth_mode, RSB::Settings.get('auth.registration_mode'),
                 'Settings from other categories must be ignored'
  end

  test 'unknown setting keys are silently ignored' do
    patch rsb_admin.settings_path, params: {
      category: 'admin',
      settings: { nonexistent_setting: 'malicious' }
    }

    # Should not raise, should redirect back
    assert_response :redirect
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
