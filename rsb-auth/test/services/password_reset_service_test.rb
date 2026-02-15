# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class PasswordResetServiceTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'reset@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        @service = RSB::Auth::PasswordResetService.new
      end

      test 'request_reset creates a reset token and enqueues email' do
        assert_difference 'RSB::Auth::PasswordResetToken.count', 1 do
          result = @service.request_reset('reset@example.com')
          assert result.success?
        end
      end

      test 'request_reset succeeds even for unknown identifier (no leak)' do
        result = @service.request_reset('unknown@example.com')
        assert result.success?
      end

      test 'reset_password with valid token resets password' do
        reset_token = @credential.password_reset_tokens.create!

        result = @service.reset_password(
          token: reset_token.token,
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        )

        assert result.success?
        assert @credential.reload.authenticate('newpassword123')
      end

      test 'reset_password marks token as used' do
        reset_token = @credential.password_reset_tokens.create!

        @service.reset_password(
          token: reset_token.token,
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        )

        assert reset_token.reload.used?
      end

      test 'reset_password revokes active sessions' do
        session = @identity.sessions.create!(
          ip_address: '127.0.0.1',
          user_agent: 'Test',
          last_active_at: Time.current
        )
        reset_token = @credential.password_reset_tokens.create!

        @service.reset_password(
          token: reset_token.token,
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        )

        assert session.reload.expired?
      end

      test 'reset_password with invalid token returns failure' do
        result = @service.reset_password(
          token: 'invalid-token',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        )

        assert_not result.success?
        assert_equal 'Invalid or expired reset token.', result.error
      end

      test 'reset_password with mismatched confirmation returns failure' do
        reset_token = @credential.password_reset_tokens.create!

        result = @service.reset_password(
          token: reset_token.token,
          password: 'newpassword123',
          password_confirmation: 'mismatch'
        )

        assert_not result.success?
      end
    end
  end
end
