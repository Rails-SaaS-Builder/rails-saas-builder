# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class VerificationServiceTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'verify@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        @service = RSB::Auth::VerificationService.new
      end

      test 'verify with valid token verifies credential' do
        @credential.update_columns(
          verification_token: 'valid-token',
          verification_sent_at: 1.hour.ago
        )

        result = @service.verify('valid-token')
        assert result.success?
        assert @credential.reload.verified?
        assert_nil @credential.verification_token
      end

      test 'verify with invalid token returns failure' do
        result = @service.verify('nonexistent-token')
        assert_not result.success?
        assert_equal 'Invalid verification token.', result.error
      end

      test 'verify with expired token returns failure' do
        @credential.update_columns(
          verification_token: 'expired-token',
          verification_sent_at: 25.hours.ago
        )

        result = @service.verify('expired-token')
        assert_not result.success?
        assert_equal 'Verification token has expired.', result.error
      end

      test 'verify fires after_identity_verified lifecycle handler' do
        @credential.update_columns(
          verification_token: 'valid-token',
          verification_sent_at: 1.hour.ago
        )

        called_with = nil
        custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_identity_verified) { |identity| called_with = identity }
        end
        stub_name = 'RSB::Auth::TestVerifiedHandler'
        RSB::Auth.const_set(:TestVerifiedHandler, custom_handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        result = @service.verify('valid-token')
        assert result.success?
        assert_equal @identity, called_with
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        RSB::Auth.send(:remove_const, :TestVerifiedHandler) if RSB::Auth.const_defined?(:TestVerifiedHandler)
      end

      test 'verify does not fire after_identity_verified on failure' do
        called = false
        custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_identity_verified) { |_| called = true }
        end
        stub_name = 'RSB::Auth::TestVerifiedNotFiredHandler'
        RSB::Auth.const_set(:TestVerifiedNotFiredHandler, custom_handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        result = @service.verify('nonexistent-token')
        assert_not result.success?
        assert_not called
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        if RSB::Auth.const_defined?(:TestVerifiedNotFiredHandler)
          RSB::Auth.send(:remove_const, :TestVerifiedNotFiredHandler)
        end
      end
    end
  end
end
