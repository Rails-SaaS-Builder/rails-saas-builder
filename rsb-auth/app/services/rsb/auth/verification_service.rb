# frozen_string_literal: true

module RSB
  module Auth
    class VerificationService
      Result = Data.define(:success?, :credential, :error)

      def send_verification(credential)
        credential.send_verification!
        Result.new(success?: true, credential: credential, error: nil)
      end

      def verify(token)
        credential = RSB::Auth::Credential.find_by(verification_token: token)
        return failure('Invalid verification token.') unless credential
        return failure('Verification token has expired.') unless credential.verification_token_valid?

        credential.verify!
        RSB::Auth.configuration.resolve_lifecycle_handler.after_identity_verified(credential.identity)
        Result.new(success?: true, credential: credential, error: nil)
      end

      private

      def failure(error)
        Result.new(success?: false, credential: nil, error: error)
      end
    end
  end
end
