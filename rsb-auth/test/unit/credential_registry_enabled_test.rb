# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialRegistryEnabledTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
        # Register per-credential enabled settings
        RSB::Settings.registry.define('auth') do
          setting :"credentials.email_password.enabled",
                  type: :boolean,
                  default: true,
                  group: 'Credential Types',
                  description: 'Enable Email & Password login'

          setting :"credentials.username_password.enabled",
                  type: :boolean,
                  default: true,
                  group: 'Credential Types',
                  description: 'Enable Username & Password login'
        end

        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :email_password,
            class_name: 'RSB::Auth::Credential::EmailPassword',
            label: 'Email & Password',
            icon: 'mail',
            form_partial: 'rsb/auth/credentials/email_password'
          )
        )
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :username_password,
            class_name: 'RSB::Auth::Credential::UsernamePassword',
            label: 'Username & Password',
            icon: 'user',
            form_partial: 'rsb/auth/credentials/username_password'
          )
        )
      end

      # --- enabled ---

      test 'enabled returns all definitions when all are enabled (default)' do
        result = RSB::Auth.credentials.enabled
        assert_equal 2, result.size
        assert_equal %i[email_password username_password], result.map(&:key)
      end

      test 'enabled excludes definitions whose setting is false' do
        with_settings('auth.credentials.username_password.enabled' => false) do
          result = RSB::Auth.credentials.enabled
          assert_equal 1, result.size
          keys = result.map(&:key)
          assert_includes keys, :email_password
          refute_includes keys, :username_password
        end
      end

      test 'enabled returns empty array when all are disabled' do
        with_settings(
          'auth.credentials.email_password.enabled' => false,
          'auth.credentials.username_password.enabled' => false
        ) do
          result = RSB::Auth.credentials.enabled
          assert_equal 0, result.size
        end
      end

      # --- enabled_keys ---

      test 'enabled_keys returns keys of enabled credential types' do
        with_settings('auth.credentials.username_password.enabled' => false) do
          keys = RSB::Auth.credentials.enabled_keys
          assert_equal [:email_password], keys
        end
      end

      # --- enabled? ---

      test 'enabled? returns true for enabled credential type' do
        assert RSB::Auth.credentials.enabled?(:email_password)
      end

      test 'enabled? returns false for disabled credential type' do
        with_settings('auth.credentials.email_password.enabled' => false) do
          refute RSB::Auth.credentials.enabled?(:email_password)
        end
      end

      test 'enabled? returns false for unknown credential type' do
        refute RSB::Auth.credentials.enabled?(:unknown_type)
      end

      # --- all still works ---

      test 'all returns all registered definitions regardless of enabled state' do
        with_settings('auth.credentials.username_password.enabled' => false) do
          result = RSB::Auth.credentials.all
          assert_equal 2, result.size
        end
      end

      # --- credential type without settings registered (backward compat) ---

      test 'enabled treats credential type as enabled when no setting exists (default true)' do
        # Register a credential type WITHOUT registering its enabled setting
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :custom_oauth,
            class_name: 'TestOAuth',
            label: 'Custom OAuth'
          )
        )

        # Should be treated as enabled since the default is true
        assert RSB::Auth.credentials.enabled?(:custom_oauth)
        assert_includes RSB::Auth.credentials.enabled.map(&:key), :custom_oauth
      end
    end
  end
end
