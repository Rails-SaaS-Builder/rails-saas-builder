# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    module Google
      class CredentialTest < ActiveSupport::TestCase
        setup do
          register_all_settings
          register_all_credentials
        end

        # --- STI inheritance ---

        test 'inherits from RSB::Auth::Credential' do
          assert RSB::Auth::Google::Credential < RSB::Auth::Credential
        end

        test 'uses rsb_auth_credentials table via STI' do
          assert_equal 'rsb_auth_credentials', RSB::Auth::Google::Credential.table_name
        end

        test 'sets type to full class name' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-123',
            password: 'not-used-but-required',
            password_confirmation: 'not-used-but-required',
            verified_at: Time.current
          )
          assert_equal 'RSB::Auth::Google::Credential', credential.type
        end

        # --- Validations ---

        test 'requires identifier' do
          credential = RSB::Auth::Google::Credential.new(
            identity: create_test_identity,
            provider_uid: 'google-uid-123',
            password: 'x', password_confirmation: 'x'
          )
          assert_not credential.valid?
          assert_includes credential.errors[:identifier], "can't be blank"
        end

        test 'validates identifier is email format' do
          credential = RSB::Auth::Google::Credential.new(
            identity: create_test_identity,
            identifier: 'not-an-email',
            provider_uid: 'google-uid-123',
            password: 'x', password_confirmation: 'x'
          )
          assert_not credential.valid?
          assert credential.errors[:identifier].any?
        end

        test 'accepts valid email identifier' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.new(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-123',
            verified_at: Time.current
          )
          credential.save(validate: false) if credential.errors[:password].any?
          credential.valid?
          assert_not credential.errors[:identifier].any?
        end

        test 'requires provider_uid' do
          credential = RSB::Auth::Google::Credential.new(
            identity: create_test_identity,
            identifier: 'user@gmail.com',
            password: 'x', password_confirmation: 'x'
          )
          assert_not credential.valid?
          assert_includes credential.errors[:provider_uid], "can't be blank"
        end

        test 'enforces provider_uid uniqueness scoped to type' do
          identity1 = create_test_identity
          identity2 = create_test_identity

          RSB::Auth::Google::Credential.create!(
            identity: identity1,
            identifier: 'user1@gmail.com',
            provider_uid: 'same-uid',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )

          duplicate = RSB::Auth::Google::Credential.new(
            identity: identity2,
            identifier: 'user2@gmail.com',
            provider_uid: 'same-uid',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )
          assert_not duplicate.valid?
          assert duplicate.errors[:provider_uid].any?
        end

        # --- Normalizations ---

        test 'normalizes identifier to lowercase' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'User@Gmail.COM',
            provider_uid: 'google-uid-456',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )
          assert_equal 'user@gmail.com', credential.identifier
        end

        # --- Custom methods ---

        test 'authenticate always returns false' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-789',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )
          assert_equal false, credential.authenticate('any-password')
        end

        test 'google_email returns identifier' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-101',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )
          assert_equal 'user@gmail.com', credential.google_email
        end

        # --- Inherited scopes ---

        test 'active scope excludes revoked credentials' do
          identity = create_test_identity
          active = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'active@gmail.com',
            provider_uid: 'uid-active',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )
          revoked = RSB::Auth::Google::Credential.create!(
            identity: create_test_identity,
            identifier: 'revoked@gmail.com',
            provider_uid: 'uid-revoked',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current,
            revoked_at: Time.current
          )

          results = RSB::Auth::Google::Credential.active
          assert_includes results, active
          assert_not_includes results, revoked
        end

        # --- Inherited revoke/restore ---

        test 'revoke! sets revoked_at' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'revoke-test@gmail.com',
            provider_uid: 'uid-revoke',
            password: 'not-used-123',
            password_confirmation: 'not-used-123',
            verified_at: Time.current
          )

          credential.revoke!
          assert credential.revoked?
          assert_not_nil credential.revoked_at
        end
      end
    end
  end
end
