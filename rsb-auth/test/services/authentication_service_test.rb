# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class AuthenticationServiceTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             lockout_threshold: 5,
                             lockout_duration: 900,
                             verification_required: false)
        register_auth_credentials
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
        # Disable verification for existing tests
        RSB::Settings.set('auth.credentials.email_password.verification_required', false)
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
      end

      test 'returns success for correct credentials' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        assert result.success?
        assert_equal @identity, result.identity
        assert_equal @credential, result.credential
        assert_nil result.error
      end

      test 'returns failure for wrong password' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'wrongpassword'
        )

        assert_not result.success?
        assert_nil result.identity
        assert_equal 'Invalid credentials.', result.error
      end

      test 'returns failure for non-existent identifier' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'nonexistent@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Invalid credentials.', result.error
      end

      test 'returns failure for locked credential' do
        @credential.update_columns(locked_until: 1.hour.from_now)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Account is locked. Try again later.', result.error
      end

      test 'returns failure for suspended identity' do
        @identity.update!(status: :suspended)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Account is suspended.', result.error
      end

      test 'resets failed_attempts to 0 on successful login' do
        @credential.update_columns(failed_attempts: 3)

        RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        @credential.reload
        assert_equal 0, @credential.failed_attempts
      end

      test 'increments failed_attempts on failed login' do
        initial_attempts = @credential.failed_attempts

        RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'wrongpassword'
        )

        @credential.reload
        assert_equal initial_attempts + 1, @credential.failed_attempts
      end

      test 'locks credential after threshold failures' do
        with_settings('auth.lockout_threshold' => 3, 'auth.lockout_duration' => 900) do
          @credential.update_columns(failed_attempts: 2)

          RSB::Auth::AuthenticationService.new.call(
            identifier: 'user@example.com',
            password: 'wrongpassword'
          )

          @credential.reload
          assert_equal 3, @credential.failed_attempts
          assert_not_nil @credential.locked_until
          assert @credential.locked_until > Time.current
        end
      end

      test 'returns failure for revoked credential' do
        @credential.update_columns(revoked_at: Time.current)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Invalid credentials.', result.error
      end

      test 'does not leak revocation status in error message' do
        @credential.update_columns(revoked_at: Time.current)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'user@example.com',
          password: 'password1234'
        )

        # Same error message as non-existent identifier — no information leakage
        assert_equal 'Invalid credentials.', result.error
      end

      # --- Credential type enforcement ---

      test 'returns failure when credential type is disabled' do
        with_settings('auth.credentials.email_password.enabled' => false) do
          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'user@example.com',
            password: 'password1234'
          )
          assert_not result.success?
          assert_equal 'This sign-in method is not available.', result.error
        end
      end

      test 'returns success when credential type is enabled' do
        with_settings('auth.credentials.email_password.enabled' => true) do
          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'user@example.com',
            password: 'password1234'
          )
          assert result.success?
        end
      end

      test 'credential type check uses no-info-leak error message' do
        with_settings('auth.credentials.email_password.enabled' => false) do
          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'user@example.com',
            password: 'password1234'
          )
          # Message should not reveal that the credential exists but type is disabled
          assert_equal 'This sign-in method is not available.', result.error
        end
      end
    end
  end
end
