# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class AuthenticationServiceDeletedTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             lockout_threshold: 5,
                             lockout_duration: 900,
                             verification_required: false)
        register_auth_credentials
        @identity = RSB::Auth::Identity.create!(status: :deleted, deleted_at: Time.current)
        # Create a credential that is technically still active (revoked_at: nil).
        # In the real deletion flow, credentials would be revoked, but we test
        # the identity-level guard in isolation — belt-and-suspenders.
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'deleted-user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
      end

      test 'authentication fails for deleted identity' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'deleted-user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_nil result.identity
        assert_nil result.credential
      end

      test 'authentication for deleted identity does not leak deletion status' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'deleted-user@example.com',
          password: 'password1234'
        )

        # Must use the same generic error as non-existent identifiers — no info leakage
        assert_equal 'Invalid credentials.', result.error
      end

      test 'authentication for deleted identity with wrong password returns same error' do
        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'deleted-user@example.com',
          password: 'wrongpassword'
        )

        # Even with wrong password, the error is generic (guard fires before password check)
        assert_equal 'Invalid credentials.', result.error
      end

      test 'authentication still works for active identity' do
        active_identity = RSB::Auth::Identity.create!(status: :active)
        active_identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'active-user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'active-user@example.com',
          password: 'password1234'
        )

        assert result.success?
        assert_equal active_identity, result.identity
      end

      test 'authentication still fails for suspended identity with unchanged error' do
        suspended_identity = RSB::Auth::Identity.create!(status: :suspended)
        suspended_identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'suspended-user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'suspended-user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Account is suspended.', result.error
      end

      test 'authentication fails for deleted identity even with correct password and no lockout' do
        # Ensure the credential is not locked and password is correct — only the
        # identity-level deletion status should block authentication.
        assert_not @credential.locked?
        assert @credential.authenticate('password1234')

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: 'deleted-user@example.com',
          password: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Invalid credentials.', result.error
      end

      test 'deleted identity check does not increment failed_attempts' do
        initial_attempts = @credential.failed_attempts

        RSB::Auth::AuthenticationService.new.call(
          identifier: 'deleted-user@example.com',
          password: 'password1234'
        )

        assert_equal initial_attempts, @credential.reload.failed_attempts
      end
    end
  end
end
