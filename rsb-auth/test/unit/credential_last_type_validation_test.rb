# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialLastTypeValidationTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
        # Register per-credential settings
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
            class_name: 'RSB::Auth::Credential::EmailPassword'
          )
        )
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :username_password,
            class_name: 'RSB::Auth::Credential::UsernamePassword'
          )
        )

        # Register the on_change callbacks (normally done in engine initializer)
        RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation
      end

      test 'can disable a credential type when another remains enabled' do
        RSB::Settings.set('auth.credentials.username_password.enabled', false)
        assert_equal false, RSB::Settings.get('auth.credentials.username_password.enabled')
      end

      test 'cannot disable the last enabled credential type' do
        # Disable username first (allowed — email is still enabled)
        RSB::Settings.set('auth.credentials.username_password.enabled', false)

        # Try to disable email (should raise — would leave zero enabled)
        error = assert_raises(RSB::Settings::ValidationError) do
          RSB::Settings.set('auth.credentials.email_password.enabled', false)
        end
        assert_match(/at least one credential type/i, error.message)

        # email_password should still be enabled
        assert_equal true, RSB::Settings.get('auth.credentials.email_password.enabled')
      end
    end
  end
end
