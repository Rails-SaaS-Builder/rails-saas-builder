# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
        @identity = RSB::Auth::Identity.create!
      end

      test 'validates type presence' do
        cred = RSB::Auth::Credential.new(
          identity: @identity,
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not cred.valid?
        assert_includes cred.errors[:type], "can't be blank"
      end

      test 'validates identifier presence' do
        cred = RSB::Auth::Credential::EmailPassword.new(
          identity: @identity,
          identifier: '',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not cred.valid?
      end

      test 'validates identifier uniqueness within type' do
        @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        other_identity = RSB::Auth::Identity.create!
        duplicate = other_identity.credentials.build(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not duplicate.valid?
      end

      test 'validates password minimum length from settings' do
        cred = RSB::Auth::Credential::EmailPassword.new(
          identity: @identity,
          identifier: 'test@example.com',
          password: 'short',
          password_confirmation: 'short'
        )
        assert_not cred.valid?
        assert(cred.errors[:password].any? { |e| e.include?('too short') })
      end

      test 'normalizes identifier to lowercase stripped' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: '  Test@Example.COM  ',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_equal 'test@example.com', cred.identifier
      end

      test 'authenticate returns truthy for correct password' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert cred.authenticate('password1234')
      end

      test 'authenticate returns false for wrong password' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not cred.authenticate('wrong')
      end

      test 'verified? returns true when verified_at is set' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          verified_at: Time.current
        )
        assert cred.verified?
      end

      test 'verified? returns false when verified_at is nil' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not cred.verified?
      end

      test 'locked? returns true when locked_until is in the future' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(locked_until: 1.hour.from_now)
        assert cred.locked?
      end

      test 'locked? returns false when locked_until is in the past' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(locked_until: 1.hour.ago)
        assert_not cred.locked?
      end

      test 'locked? returns false when locked_until is nil' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not cred.locked?
      end

      test 'verify! sets verified_at and clears verification_token' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(verification_token: 'token123')
        cred.verify!
        assert cred.verified?
        assert_nil cred.verification_token
      end

      test 'verification_token_valid? returns true when fresh' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(
          verification_token: 'token123',
          verification_sent_at: 1.hour.ago
        )
        assert cred.verification_token_valid?
      end

      test 'verification_token_valid? returns false when expired' do
        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(
          verification_token: 'token123',
          verification_sent_at: 25.hours.ago
        )
        assert_not cred.verification_token_valid?
      end

      test 'after_credential_locked lifecycle handler fires when locked' do
        called_with = nil
        custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_credential_locked) { |credential| called_with = credential }
        end
        stub_name = 'RSB::Auth::TestCredentialLockedHandler'
        RSB::Auth.const_set(:TestCredentialLockedHandler, custom_handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        cred = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update!(locked_until: 1.hour.from_now)
        assert_equal cred, called_with
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        if RSB::Auth.const_defined?(:TestCredentialLockedHandler)
          RSB::Auth.send(:remove_const, :TestCredentialLockedHandler)
        end
      end
    end
  end
end
