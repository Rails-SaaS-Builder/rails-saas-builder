# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class PasswordResetTokenTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'reset-test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
      end

      test 'generates token on creation' do
        token = @credential.password_reset_tokens.create!
        assert token.token.present?
        assert token.token.length >= 32
      end

      test 'sets expiry on creation (2 hours)' do
        freeze_time do
          token = @credential.password_reset_tokens.create!
          assert_equal 2.hours.from_now, token.expires_at
        end
      end

      test 'expired? returns true when expired' do
        token = @credential.password_reset_tokens.create!
        token.update_columns(expires_at: 1.hour.ago)
        assert token.expired?
      end

      test 'expired? returns false when not expired' do
        token = @credential.password_reset_tokens.create!
        assert_not token.expired?
      end

      test 'used? returns true when used' do
        token = @credential.password_reset_tokens.create!
        token.use!
        assert token.used?
      end

      test 'used? returns false when not used' do
        token = @credential.password_reset_tokens.create!
        assert_not token.used?
      end

      test 'use! marks token as used' do
        freeze_time do
          token = @credential.password_reset_tokens.create!
          token.use!
          assert_equal Time.current, token.used_at
        end
      end

      test 'valid scope returns unused non-expired tokens' do
        valid_token = @credential.password_reset_tokens.create!

        expired_token = @credential.password_reset_tokens.create!
        expired_token.update_columns(expires_at: 1.hour.ago)

        used_token = @credential.password_reset_tokens.create!
        used_token.use!

        valid_tokens = RSB::Auth::PasswordResetToken.valid
        assert_includes valid_tokens, valid_token
        assert_not_includes valid_tokens, expired_token
        assert_not_includes valid_tokens, used_token
      end
    end
  end
end
