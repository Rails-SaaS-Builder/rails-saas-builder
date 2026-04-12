# frozen_string_literal: true

module RSB
  module Auth
    class RegistrationService
      Result = Data.define(:success?, :identity, :credential, :errors)

      # Registers a new identity with a credential.
      #
      # @param identifier [String] login identifier (email, phone, username)
      # @param password [String] password
      # @param password_confirmation [String] password confirmation
      # @param credential_type [Symbol, String, nil] explicit credential type key.
      #   When nil, falls back to `auth.login_identifier` setting (backward compat).
      # @param recovery_email [String, nil] optional recovery email for username credentials
      # @param invite_token [String, nil] invitation token (validated when mode is invite_only)
      # @return [Result]
      def call(identifier:, password:, password_confirmation:, credential_type: nil, recovery_email: nil,
               invite_token: nil)
        mode = RSB::Settings.get('auth.registration_mode')
        return failure('Registration is disabled.') if mode.to_s == 'disabled'

        invitation = nil
        if mode.to_s == 'invite_only'
          return failure('Registration requires an invitation') if invite_token.blank?

          invitation = RSB::Auth::Invitation.pending.find_by(token: invite_token)
          return failure('Invalid or expired invitation') unless invitation
        elsif invite_token.present?
          # Open mode: track invitation if valid, silently ignore if not
          invitation = RSB::Auth::Invitation.pending.find_by(token: invite_token)
        end

        resolved = resolve_credential_type(credential_type)
        return failure('This registration method is not available.') unless resolved

        # Check per-credential registerable setting
        resolved_key = credential_type_key_from_class(resolved)
        if resolved_key
          registerable = RSB::Settings.get("auth.credentials.#{resolved_key}.registerable")
          unless ActiveModel::Type::Boolean.new.cast(registerable)
            return failure('This registration method is not available.')
          end
        end

        ActiveRecord::Base.transaction do
          identity = RSB::Auth::Identity.create!
          credential = identity.credentials.create!(
            type: resolved,
            identifier: identifier,
            password: password,
            password_confirmation: password_confirmation,
            recovery_email: recovery_email
          )

          # Per-credential verification behavior
          if resolved_key
            auto_verify = ActiveModel::Type::Boolean.new.cast(
              RSB::Settings.get("auth.credentials.#{resolved_key}.auto_verify_on_signup")
            )
            verif_required = ActiveModel::Type::Boolean.new.cast(
              RSB::Settings.get("auth.credentials.#{resolved_key}.verification_required")
            )

            if auto_verify
              credential.update_column(:verified_at, Time.current)
            elsif verif_required
              credential.send_verification!
            end
          elsif RSB::Settings.get('auth.verification_required')
            # Fallback to global setting (backward compat)
            credential.send_verification!
          end

          if invitation
            invitation.use!
            identity.update!(metadata: (identity.metadata || {}).merge('invitation_id' => invitation.id))
            RSB::Auth.configuration.resolve_lifecycle_handler.after_invitation_used(invitation, identity)
          end

          Result.new(success?: true, identity: identity, credential: credential, errors: [])
        end
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages)
      end

      # Creates identity + credential for OAuth/external registration.
      # Used by OAuth callback services to delegate identity creation.
      #
      # @param credential_class [String] fully-qualified STI class name
      # @param identifier [String] email or other identifier from the OAuth provider
      # @param invite_token [String, nil] invitation token (validated when mode is invite_only)
      # @param credential_attrs [Hash] additional credential attributes (e.g., provider_uid)
      # @return [Result]
      def register_external(credential_class:, identifier:, invite_token: nil, **credential_attrs)
        mode = RSB::Settings.get('auth.registration_mode')
        return failure('Registration is currently disabled.') if mode.to_s == 'disabled'

        invitation = nil
        if mode.to_s == 'invite_only'
          return failure('Registration requires an invitation') if invite_token.blank?

          invitation = RSB::Auth::Invitation.pending.find_by(token: invite_token)
          return failure('Invalid or expired invitation') unless invitation
        elsif invite_token.present?
          invitation = RSB::Auth::Invitation.pending.find_by(token: invite_token)
        end

        identity = nil
        credential = nil

        ActiveRecord::Base.transaction do
          identity = RSB::Auth::Identity.create!(status: :active)

          credential = credential_class.constantize.create!(
            identity: identity,
            identifier: identifier,
            verified_at: Time.current,
            **credential_attrs
          )

          if invitation
            invitation.use!
            identity.update!(metadata: (identity.metadata || {}).merge('invitation_id' => invitation.id))
            RSB::Auth.configuration.resolve_lifecycle_handler.after_invitation_used(invitation, identity)
          end
        end

        Result.new(success?: true, identity: identity, credential: credential, errors: [])
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, identity: nil, credential: nil, errors: e.record.errors.full_messages)
      rescue RuntimeError => e
        Result.new(success?: false, identity: nil, credential: nil, errors: [e.message])
      end

      private

      # Resolves the credential class name from an explicit type key or the
      # login_identifier setting (backward compat).
      #
      # @param credential_type [Symbol, String, nil]
      # @return [String, nil] STI class name, or nil if invalid/disabled
      def resolve_credential_type(credential_type)
        if credential_type.present?
          # Explicit credential type
          key = credential_type.to_sym
          definition = RSB::Auth.credentials.find(key)
          return nil unless definition
          return nil unless definition.registerable
          return nil unless RSB::Auth.credentials.enabled?(key)

        else
          # Backward compat: fall back to login_identifier
          identifier = RSB::Settings.get('auth.login_identifier')
          definition = RSB::Auth.credentials.for_identifier(identifier)
          return nil unless definition
          return nil unless RSB::Auth.credentials.enabled?(definition.key)

        end
        definition.class_name
      end

      def credential_type_key_from_class(class_name)
        class_name.demodulize.underscore.to_sym
      rescue StandardError
        nil
      end

      def failure(errors)
        errors = Array(errors)
        Result.new(success?: false, identity: nil, credential: nil, errors: errors)
      end
    end
  end
end
