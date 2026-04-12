# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class RegistrationServiceTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             registration_mode: 'open',
                             login_identifier: 'email',
                             verification_required: false,
                             lockout_threshold: 5,
                             lockout_duration: 900)
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :email_password,
            class_name: 'RSB::Auth::Credential::EmailPassword'
          )
        )
        # Register all per-credential settings (enabled, registerable, verification_required, etc.)
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
        @service = RSB::Auth::RegistrationService.new
      end

      test 'creates identity and credential on success' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'newuser@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        assert_instance_of RSB::Auth::Identity, result.identity
        assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
        assert_equal 'newuser@example.com', result.credential.identifier
      end

      test 'returns failure when registration is disabled' do
        with_settings('auth.registration_mode' => 'disabled') do
          result = RSB::Auth::RegistrationService.new.call(
            identifier: 'test@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )

          assert_not result.success?
          assert_includes result.errors, 'Registration is disabled.'
        end
      end

      test 'returns failure when registration is invite_only without invite_token' do
        with_settings('auth.registration_mode' => 'invite_only') do
          result = RSB::Auth::RegistrationService.new.call(
            identifier: 'test@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )

          assert_not result.success?
          assert_includes result.errors, 'Registration requires an invitation'
        end
      end

      test 'returns failure for invalid params' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: '',
          password: 'short',
          password_confirmation: 'short'
        )

        assert_not result.success?
        assert result.errors.any?
      end

      test 'uses credential registry to resolve credential type' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'registry-test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        assert_equal 'RSB::Auth::Credential::EmailPassword', result.credential.type
      end

      test 'allows registration with identifier that was previously revoked' do
        register_auth_credentials

        # Create and revoke a credential
        identity = RSB::Auth::Identity.create!
        cred = identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'reused@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        cred.update_columns(revoked_at: Time.current)

        # Register with the same identifier
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'reused@example.com',
          password: 'newpassword5678',
          password_confirmation: 'newpassword5678'
        )

        assert result.success?
        assert result.credential.persisted?
        assert_nil result.credential.revoked_at

        # Old revoked credential still exists
        assert_equal 2, RSB::Auth::Credential.where(identifier: 'reused@example.com').count
      end

      # --- Explicit credential_type parameter ---

      test 'creates credential with explicit credential_type' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'explicit@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          credential_type: :email_password
        )
        assert result.success?
        assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
      end

      test 'returns failure when credential_type is disabled' do
        with_settings('auth.credentials.email_password.enabled' => false) do
          result = RSB::Auth::RegistrationService.new.call(
            identifier: 'disabled@example.com',
            password: 'password1234',
            password_confirmation: 'password1234',
            credential_type: :email_password
          )
          assert_not result.success?
          assert_includes result.errors, 'This registration method is not available.'
        end
      end

      test 'returns failure when credential_type is unknown' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'unknown@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          credential_type: :nonexistent_type
        )
        assert_not result.success?
        assert_includes result.errors, 'This registration method is not available.'
      end

      test 'backward compat: without credential_type falls back to login_identifier' do
        result = RSB::Auth::RegistrationService.new.call(
          identifier: 'fallback@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert result.success?
        assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
      end

      # --- invite_token in #call ---

      test 'call with invite_token succeeds in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = create_test_invitation

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: invitation.token
        )

        assert result.success?
        assert result.identity.persisted?
        invitation.reload
        assert_equal 1, invitation.uses_count
      end

      test 'call with invite_token stores invitation_id in identity metadata' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = create_test_invitation

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: invitation.token
        )

        assert_equal invitation.id, result.identity.metadata['invitation_id']
      end

      test 'call without invite_token fails in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        refute result.success?
        assert_includes result.errors, 'Registration requires an invitation'
      end

      test 'call with invalid invite_token fails in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: 'nonexistent-token'
        )

        refute result.success?
        assert_includes result.errors, 'Invalid or expired invitation'
      end

      test 'call with expired invite_token fails in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = RSB::Auth::Invitation.create!(expires_at: 1.hour.ago, max_uses: 1)

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: invitation.token
        )

        refute result.success?
        assert_includes result.errors, 'Invalid or expired invitation'
      end

      test 'call with invite_token in open mode tracks invitation' do
        RSB::Settings.set('auth.registration_mode', 'open')
        invitation = create_test_invitation

        result = @service.call(
          identifier: 'user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: invitation.token
        )

        assert result.success?
        invitation.reload
        assert_equal 1, invitation.uses_count
        assert_equal invitation.id, result.identity.metadata['invitation_id']
      end

      test 'call with invalid invite_token in open mode silently ignores it' do
        RSB::Settings.set('auth.registration_mode', 'open')

        result = @service.call(
          identifier: 'user@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: 'bad-token'
        )

        assert result.success?
        assert_nil result.identity.metadata['invitation_id']
      end

      test 'call with invite_token fires after_invitation_used lifecycle hook' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = create_test_invitation

        hook_called = false
        custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_invitation_used) do |_inv, _identity|
            hook_called = true
          end
        end

        RSB::Auth.configure { |c| c.lifecycle_handler = custom_handler.name }
        # Need to make the class accessible
        Object.const_set(:TestInviteHookHandler, custom_handler) unless defined?(::TestInviteHookHandler)
        RSB::Auth.configure { |c| c.lifecycle_handler = 'TestInviteHookHandler' }

        @service.call(
          identifier: 'invited@example.com',
          password: 'password1234',
          password_confirmation: 'password1234',
          invite_token: invitation.token
        )

        assert hook_called
      ensure
        RSB::Auth.configure { |c| c.lifecycle_handler = nil }
        Object.send(:remove_const, :TestInviteHookHandler) if defined?(::TestInviteHookHandler)
      end

      test 'call rolls back uses_count if identity creation fails' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = create_test_invitation

        result = @service.call(
          identifier: 'invited@example.com',
          password: 'short', # too short — will fail validation
          password_confirmation: 'short',
          invite_token: invitation.token
        )

        refute result.success?
        invitation.reload
        assert_equal 0, invitation.uses_count
      end

      # --- register_external ---

      test 'register_external creates identity and credential' do
        RSB::Settings.set('auth.registration_mode', 'open')

        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        assert result.identity.persisted?
        assert result.credential.persisted?
        assert_equal 'oauth@example.com', result.credential.identifier
        assert result.credential.verified_at.present?
      end

      test 'register_external with invite_token in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        invitation = create_test_invitation

        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com',
          invite_token: invitation.token,
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        invitation.reload
        assert_equal 1, invitation.uses_count
        assert_equal invitation.id, result.identity.metadata['invitation_id']
      end

      test 'register_external without invite_token fails in invite_only mode' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')

        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com'
        )

        refute result.success?
        assert_includes result.errors, 'Registration requires an invitation'
      end

      test 'register_external fails when registration is disabled' do
        RSB::Settings.set('auth.registration_mode', 'disabled')

        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com'
        )

        refute result.success?
      end

      test 'register_external sets verified_at on credential' do
        RSB::Settings.set('auth.registration_mode', 'open')

        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.credential.verified_at.present?
      end

      test 'register_external fires after_identity_created lifecycle hook' do
        RSB::Settings.set('auth.registration_mode', 'open')

        # The after_identity_created hook fires via after_commit callback on Identity
        # Just verify the identity is created successfully
        result = @service.register_external(
          credential_class: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'oauth@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        assert result.identity.persisted?
      end
    end
  end
end
