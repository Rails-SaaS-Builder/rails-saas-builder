# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialSoftDeleteTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
        @identity = RSB::Auth::Identity.create!
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
      end

      # --- Scopes ---

      test 'active scope returns only non-revoked credentials' do
        revoked = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'revoked@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        revoked.update_columns(revoked_at: Time.current)

        result = RSB::Auth::Credential.active
        assert_includes result, @credential
        assert_not_includes result, revoked
      end

      test 'revoked scope returns only revoked credentials' do
        revoked = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'revoked@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        revoked.update_columns(revoked_at: Time.current)

        result = RSB::Auth::Credential.revoked
        assert_includes result, revoked
        assert_not_includes result, @credential
      end

      # --- Predicate ---

      test 'revoked? returns true when revoked_at is set' do
        @credential.update_columns(revoked_at: Time.current)
        assert @credential.revoked?
      end

      test 'revoked? returns false when revoked_at is nil' do
        assert_not @credential.revoked?
      end

      # --- revoke! ---

      test 'revoke! sets revoked_at to current time' do
        freeze_time do
          @credential.revoke!
          assert_equal Time.current, @credential.revoked_at
        end
      end

      test 'revoke! does not delete the record' do
        assert_no_difference 'RSB::Auth::Credential.count' do
          @credential.revoke!
        end
      end

      test 'revoke! fires after_credential_revoked lifecycle handler' do
        called_with = nil
        handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_credential_revoked) { |credential| called_with = credential }
        end
        stub_name = 'RSB::Auth::TestRevokedHandler'
        RSB::Auth.const_set(:TestRevokedHandler, handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        @credential.revoke!
        assert_equal @credential, called_with
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        RSB::Auth.send(:remove_const, :TestRevokedHandler) if RSB::Auth.const_defined?(:TestRevokedHandler)
      end

      # --- restore! ---

      test 'restore! clears revoked_at' do
        @credential.update_columns(revoked_at: Time.current)
        @credential.restore!
        assert_nil @credential.revoked_at
      end

      test 'restore! raises CredentialConflictError when active duplicate exists' do
        @credential.update_columns(revoked_at: Time.current)

        # Create a new active credential with the same identifier
        other_identity = RSB::Auth::Identity.create!
        other_identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_raises(RSB::Auth::CredentialConflictError) do
          @credential.restore!
        end
        assert_not_nil @credential.reload.revoked_at # still revoked
      end

      test 'restore! succeeds when no active duplicate exists' do
        @credential.update_columns(revoked_at: Time.current)
        assert_nothing_raised { @credential.restore! }
        assert_nil @credential.revoked_at
      end

      test 'restore! fires after_credential_restored lifecycle handler' do
        @credential.update_columns(revoked_at: Time.current)
        called_with = nil
        handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_credential_restored) { |credential| called_with = credential }
        end
        stub_name = 'RSB::Auth::TestRestoredHandler'
        RSB::Auth.const_set(:TestRestoredHandler, handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        @credential.restore!
        assert_equal @credential, called_with
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        RSB::Auth.send(:remove_const, :TestRestoredHandler) if RSB::Auth.const_defined?(:TestRestoredHandler)
      end

      # --- Partial unique index ---

      test 'same identifier can be registered after revocation' do
        @credential.revoke!

        other_identity = RSB::Auth::Identity.create!
        new_cred = other_identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert new_cred.persisted?
      end

      test 'same identifier cannot be registered while active' do
        other_identity = RSB::Auth::Identity.create!
        duplicate = other_identity.credentials.build(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_not duplicate.valid?
        assert_includes duplicate.errors[:identifier], 'has already been taken'
      end

      # --- Identity association ---

      test 'identity.credentials returns all (active + revoked)' do
        revoked = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'revoked@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        revoked.update_columns(revoked_at: Time.current)

        assert_includes @identity.credentials, @credential
        assert_includes @identity.credentials, revoked
      end

      test 'identity.active_credentials returns only active' do
        revoked = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'revoked@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        revoked.update_columns(revoked_at: Time.current)

        assert_includes @identity.active_credentials, @credential
        assert_not_includes @identity.active_credentials, revoked
      end

      test 'identity.primary_credential skips revoked credentials' do
        @credential.update_columns(revoked_at: Time.current)

        second = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'second@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_equal second, @identity.primary_credential
      end

      test 'identity.primary_credential returns nil when all credentials revoked' do
        @credential.update_columns(revoked_at: Time.current)
        assert_nil @identity.primary_credential
      end

      test 'destroying identity destroys all credentials including revoked' do
        @credential.update_columns(revoked_at: Time.current)
        assert_difference 'RSB::Auth::Credential.count', -1 do
          @identity.destroy!
        end
      end
    end
  end
end
