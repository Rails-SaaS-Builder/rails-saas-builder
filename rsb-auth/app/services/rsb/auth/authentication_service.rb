# frozen_string_literal: true

require 'bcrypt'

module RSB
  module Auth
    class AuthenticationService
      Result = Data.define(:success?, :identity, :credential, :error, :unverified)

      # Cached bcrypt digest for timing attack prevention.
      DUMMY_DIGEST = BCrypt::Password.create('dummy_password_for_timing')

      # Authenticates by identifier and password. Only active (non-revoked) credentials
      # are considered. Also checks that the credential's type is currently enabled
      # via settings.
      #
      # @param identifier [String] login identifier (e.g. email)
      # @param password [String] password
      # @return [Result] success? with identity/credential, or error message
      def call(identifier:, password:)
        normalized = identifier.strip.downcase
        credential = RSB::Auth::Credential.active.find_by(identifier: normalized)

        unless credential
          # Perform a dummy bcrypt comparison to equalize response timing
          DUMMY_DIGEST.is_password?(password)
          return Result.new(success?: false, identity: nil, credential: nil, error: 'Invalid credentials.',
                            unverified: false)
        end

        return failure('Invalid credentials.') if credential.identity.deleted?

        # Check credential type is enabled
        credential_type_key = derive_credential_type_key(credential)
        unless RSB::Auth.credentials.enabled?(credential_type_key)
          return failure(error_message('This sign-in method is not available.'))
        end

        return failure(error_message('Account is locked. Try again later.')) if credential.locked?
        return failure(error_message('Account is suspended.')) if credential.identity.suspended?

        if credential.authenticate(password)
          credential.update_columns(failed_attempts: 0) if credential.failed_attempts > 0

          # Per-credential verification check
          verif_required = ActiveModel::Type::Boolean.new.cast(
            RSB::Settings.get("auth.credentials.#{credential_type_key}.verification_required")
          )

          if verif_required && !credential.verified?
            allow_unverified = ActiveModel::Type::Boolean.new.cast(
              RSB::Settings.get("auth.credentials.#{credential_type_key}.allow_login_unverified")
            )

            if allow_unverified
              Result.new(success?: true, identity: credential.identity, credential: credential, error: nil,
                         unverified: true)
            else
              failure('Please verify your email before signing in.')
            end
          else
            Result.new(success?: true, identity: credential.identity, credential: credential, error: nil,
                       unverified: false)
          end
        else
          record_failed_attempt(credential)
          failure('Invalid credentials.')
        end
      end

      private

      def error_message(specific_message)
        if RSB::Settings.get('auth.generic_error_messages')
          'Invalid credentials.'
        else
          specific_message
        end
      end

      # Derives the credential type key from a credential's STI type.
      # E.g., "RSB::Auth::Credential::EmailPassword" -> :email_password
      #
      # @param credential [RSB::Auth::Credential]
      # @return [Symbol]
      def derive_credential_type_key(credential)
        credential.type.demodulize.underscore.to_sym
      end

      def record_failed_attempt(credential)
        credential.increment!(:failed_attempts)
        threshold = RSB::Settings.get('auth.lockout_threshold')
        return unless credential.failed_attempts >= threshold

        duration = RSB::Settings.get('auth.lockout_duration')
        credential.update_columns(locked_until: Time.current + duration.to_i.seconds)
      end

      def failure(error)
        Result.new(success?: false, identity: nil, credential: nil, error: error, unverified: false)
      end
    end
  end
end
