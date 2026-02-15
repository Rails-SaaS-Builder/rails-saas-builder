# frozen_string_literal: true

module RSB
  module Auth
    class PasswordResetService
      Result = Data.define(:success?, :error)

      def request_reset(identifier)
        normalized = identifier.to_s.strip.downcase

        # Try lookup by identifier first, then by recovery_email
        credential = RSB::Auth::Credential.active.find_by(identifier: normalized)
        credential ||= RSB::Auth::Credential.active.find_by(recovery_email: normalized)

        if credential
          reset_token = credential.password_reset_tokens.create!
          email = credential.deliverable_email
          RSB::Auth::AuthMailer.password_reset(credential, reset_token).deliver_later if email.present?
        end

        Result.new(success?: true, error: nil)
      end

      def reset_password(token:, password:, password_confirmation:)
        reset_token = RSB::Auth::PasswordResetToken.valid.find_by(token: token)
        return failure('Invalid or expired reset token.') unless reset_token

        credential = reset_token.credential
        credential.password = password
        credential.password_confirmation = password_confirmation

        if credential.save
          reset_token.use!
          credential.identity.sessions.active.update_all(expires_at: Time.current)
          Result.new(success?: true, error: nil)
        else
          failure(credential.errors.full_messages.join(', '))
        end
      end

      private

      def failure(error)
        Result.new(success?: false, error: error)
      end
    end
  end
end
