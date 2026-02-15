# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialDeprecationBridgeTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
        RSB::Settings.registry.define('auth') do
          setting :"credentials.email_password.enabled",
                  type: :boolean, default: true,
                  group: 'Credential Types', description: 'Enable Email & Password'
          setting :"credentials.username_password.enabled",
                  type: :boolean, default: true,
                  group: 'Credential Types', description: 'Enable Username & Password'
        end
        register_all_auth_credentials
      end

      test 'when per-credential settings are explicitly set, login_identifier is ignored' do
        # Explicitly set per-credential settings
        RSB::Settings.set('auth.credentials.email_password.enabled', true)
        RSB::Settings.set('auth.credentials.username_password.enabled', false)

        # Set login_identifier to something different
        RSB::Settings.set('auth.login_identifier', 'username')

        # Per-credential settings should win
        enabled = RSB::Auth.credentials.enabled_keys
        assert_includes enabled, :email_password
        refute_includes enabled, :username_password
      end

      test 'login_identifier deprecation warning is logged' do
        deprecation_warnings = []
        RSB::Auth::CredentialDeprecationBridge.on_deprecation do |message|
          deprecation_warnings << message
        end

        RSB::Auth::CredentialDeprecationBridge.resolve_from_login_identifier

        assert(deprecation_warnings.any? { |w| w.include?('login_identifier') })
      ensure
        RSB::Auth::CredentialDeprecationBridge.clear_deprecation_handler
      end

      test 'login_identifier email maps to email_password enabled only' do
        result = RSB::Auth::CredentialDeprecationBridge.enabled_map_for('email')

        assert_equal true, result[:email_password]
        assert_equal false, result[:username_password]
      end

      test 'login_identifier username maps to username_password enabled only' do
        result = RSB::Auth::CredentialDeprecationBridge.enabled_map_for('username')

        assert_equal false, result[:email_password]
        assert_equal true, result[:username_password]
      end
    end
  end
end
