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

    # rsb-entitlements registers "entitlements"
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

  test 'entitlements settings have all expected keys' do
    schema = RSB::Settings.registry.for('entitlements')
    expected_keys = %i[default_currency trial_days grace_period_days auto_create_counters]
    expected_keys.each do |key|
      assert_includes schema.keys, key, "Missing entitlements setting: #{key}"
    end
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
    assert_equal 'usd', RSB::Settings.get('entitlements.default_currency')
    assert_equal 'default', RSB::Settings.get('admin.theme')
  end
end
