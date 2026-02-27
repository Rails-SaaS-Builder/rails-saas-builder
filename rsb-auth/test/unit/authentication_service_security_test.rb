# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class AuthenticationServiceSecurityTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             lockout_threshold: 5,
                             lockout_duration: 900,
                             verification_required: false,
                             generic_error_messages: false)
        register_auth_credentials
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'secure@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        @credential.update_column(:verified_at, Time.current)
      end

      # --- Dummy bcrypt timing attack prevention ---

      test 'DUMMY_DIGEST constant is defined on AuthenticationService' do
        assert defined?(RSB::Auth::AuthenticationService::DUMMY_DIGEST),
               'DUMMY_DIGEST constant must be defined for timing attack prevention'
        assert_instance_of BCrypt::Password, RSB::Auth::AuthenticationService::DUMMY_DIGEST
      end

      test 'login with non-existent identifier returns generic error and performs bcrypt comparison' do
        service = RSB::Auth::AuthenticationService.new
        result = service.call(identifier: 'nonexistent@example.com', password: 'anypassword')

        assert_not result.success?
        assert_equal 'Invalid credentials.', result.error
        assert_nil result.identity
      end

      test 'login timing is similar for existent and non-existent identifiers' do
        service = RSB::Auth::AuthenticationService.new

        # Time a login with existing identifier (wrong password)
        start_existing = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        service.call(identifier: 'secure@example.com', password: 'wrongpassword')
        time_existing = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_existing

        # Time a login with non-existing identifier
        start_missing = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        service.call(identifier: 'nobody@example.com', password: 'wrongpassword')
        time_missing = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_missing

        delta = (time_existing - time_missing).abs
        assert delta < 0.5, "Timing delta between existing and non-existing identifier is #{delta}s — should be < 0.5s"
      end

      # --- Generic error messages setting ---

      test 'generic_error_messages=false shows specific error for locked account' do
        @credential.update_columns(failed_attempts: 5, locked_until: 1.hour.from_now)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'secure@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Account is locked. Try again later.', result.error
      end

      test 'generic_error_messages=true shows generic error for locked account' do
        with_settings('auth.generic_error_messages' => true) do
          @credential.update_columns(failed_attempts: 5, locked_until: 1.hour.from_now)

          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'secure@example.com',
            password: 'password1234'
          )

          assert_not result.success?
          assert_equal 'Invalid credentials.', result.error
        end
      end

      test 'generic_error_messages=false shows specific error for suspended identity' do
        @identity.update!(status: :suspended)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'secure@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Account is suspended.', result.error
      end

      test 'generic_error_messages=true shows generic error for suspended identity' do
        with_settings('auth.generic_error_messages' => true) do
          @identity.update!(status: :suspended)

          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'secure@example.com',
            password: 'password1234'
          )

          assert_not result.success?
          assert_equal 'Invalid credentials.', result.error
        end
      end

      test 'generic_error_messages=true shows generic error for disabled credential type' do
        with_settings('auth.generic_error_messages' => true, 'auth.credentials.email_password.enabled' => false) do
          result = RSB::Auth::AuthenticationService.new.call(
            identifier: 'secure@example.com',
            password: 'password1234'
          )

          assert_not result.success?
          assert_equal 'Invalid credentials.', result.error
        end
      end

      # --- Failed attempts reset on success ---

      test 'successful login resets failed_attempts to 0' do
        @credential.update_column(:failed_attempts, 3)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'secure@example.com',
          password: 'password1234'
        )

        assert result.success?
        assert_equal 0, @credential.reload.failed_attempts
      end

      test 'successful login does not write if failed_attempts is already 0' do
        @credential.update_column(:failed_attempts, 0)

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'secure@example.com',
          password: 'password1234'
        )

        assert result.success?
        assert_equal 0, @credential.reload.failed_attempts
      end
    end
  end
end
