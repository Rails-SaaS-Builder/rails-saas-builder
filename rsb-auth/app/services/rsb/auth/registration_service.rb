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
      # @return [Result]
      def call(identifier:, password:, password_confirmation:, credential_type: nil, recovery_email: nil)
        registration_mode = RSB::Settings.get('auth.registration_mode')
        return failure('Registration is disabled.') if registration_mode.to_s == 'disabled'
        return failure('Registration is invite-only.') if registration_mode.to_s == 'invite_only'

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

          Result.new(success?: true, identity: identity, credential: credential, errors: [])
        end
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages)
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
