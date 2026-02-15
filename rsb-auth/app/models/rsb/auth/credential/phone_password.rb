# frozen_string_literal: true

module RSB
  module Auth
    class Credential::PhonePassword < Credential
      # NOTE: This credential type is intentionally unregistered from the credential
      # registry. There is no SMS provider integrated, so phone-based verification
      # and password reset emails would silently fail (the mailer sends to the phone
      # number as if it were an email address). The model, form partials, and admin
      # form partial are kept in the codebase for future SMS provider support.
      # To re-enable, add the CredentialDefinition registration back to engine.rb.

      validates :identifier, format: { with: /\A\+?[\d\s\-().]+\z/ }
    end
  end
end
