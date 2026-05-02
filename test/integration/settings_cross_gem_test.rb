# frozen_string_literal: true

require 'test_helper'

class SettingsCrossGemTest < ActiveSupport::TestCase
  setup do
    register_all_settings
  end

  test 'all gem settings are registered' do
    categories = RSB::Settings.registry.categories

    # rsb-auth registers "auth"
    assert_includes categories, 'auth'

    # rsb-entitlements registers "entitlements" (intentionally empty in v1)
    assert_includes categories, 'entitlements'

    # rsb-admin registers "admin"
    assert_includes categories, 'admin'
  end

  test 'auth settings have all expected keys' do
    schema = RSB::Settings.registry.for('auth')
    expected_keys = %i[
      registration_mode login_identifier password_min_length
      session_duration max_sessions lockout_threshold
      lockout_duration verification_required
    ]
    expected_keys.each do |key|
      assert_includes schema.keys, key, "Missing auth setting: #{key}"
    end
  end

  test 'entitlements v1 settings schema is registered (intentionally empty)' do
    schema = RSB::Settings.registry.for('entitlements')
    # v1 has no entitlements-level settings — provider settings live in provider gems.
    assert schema, 'entitlements schema should be registered'
    refute schema.keys.include?(:default_currency),
           'v0 default_currency setting must not be present in v1'
    refute schema.keys.include?(:trial_days),
           'v0 trial_days setting must not be present in v1'
  end

  test 'admin settings have all expected keys' do
    schema = RSB::Settings.registry.for('admin')
    expected_keys = %i[theme per_page app_name]
    expected_keys.each do |key|
      assert_includes schema.keys, key, "Missing admin setting: #{key}"
    end
  end

  test 'settings resolution works across gems with defaults' do
    assert_equal 'open', RSB::Settings.get('auth.registration_mode')
    assert_equal 'default', RSB::Settings.get('admin.theme')
  end
end
