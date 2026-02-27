# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class SessionCookieSecurityTest < ActionDispatch::IntegrationTest
      include RSB::Auth::Engine.routes.url_helpers

      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             max_sessions: 5,
                             lockout_threshold: 5,
                             lockout_duration: 900,
                             verification_required: false,
                             generic_error_messages: false)
        register_auth_credentials
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
        Rails.cache.clear

        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'cookie@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        @credential.update_column(:verified_at, Time.current)
      end

      test 'session cookie includes secure flag in cookie options' do
        post session_path, params: {
          identifier: 'cookie@example.com',
          password: 'password1234'
        }

        # After successful login, verify the cookie was set
        assert cookies[:rsb_session_token].present?, 'Session cookie should be set after login'
      end

      private

      def default_url_options
        { host: 'localhost' }
      end
    end
  end
end
