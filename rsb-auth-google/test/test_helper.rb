# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'
require 'rsb/settings/test_helper'
require 'rsb/auth/test_helper'
require 'rsb/auth/google/test_helper'

ActiveRecord::Migration.maintain_test_schema!

module ActiveSupport
  class TestCase
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
    include RSB::Auth::Google::TestHelper

    def register_all_settings
      RSB::Settings.registry.register(RSB::Auth.settings_schema)
      RSB::Settings.registry.register(RSB::Auth::Google::SettingsSchema.build)
    end

    def register_all_credentials
      register_all_auth_credentials
      register_google_credential
      RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
      RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation
      RSB::Settings.configure do |config|
        config.set 'auth.credentials.google.verification_required', false
        config.set 'auth.credentials.google.auto_verify_on_signup', true
        config.set 'auth.credentials.google.allow_login_unverified', true
      end
    end

    private

    def register_google_credential
      return if RSB::Auth.credentials.find(:google)

      RSB::Auth.credentials.register(
        RSB::Auth::CredentialDefinition.new(
          key: :google,
          class_name: 'RSB::Auth::Google::Credential',
          authenticatable: true,
          registerable: true,
          label: 'Google',
          icon: 'google',
          form_partial: 'rsb/auth/google/credentials/google',
          redirect_url: '/auth/oauth/google',
          admin_form_partial: nil
        )
      )
    end
  end
end
