# frozen_string_literal: true

module RSB
  module Auth
    module Google
      class Credential < RSB::Auth::Credential
        PLACEHOLDER_DIGEST = '$2a$04$placeholder.digest.for.google.oauth.credentials.only'

        before_validation :set_placeholder_digest, if: -> { password_digest.blank? }

        validates :identifier, format: { with: URI::MailTo::EMAIL_REGEXP }
        validates :provider_uid, presence: true
        validates :provider_uid, uniqueness: { scope: :type, conditions: -> { where(revoked_at: nil) } }

        def authenticate(_password)
          false
        end

        def google_email
          identifier
        end

        private

        def password_required?
          false
        end

        def set_placeholder_digest
          self.password_digest = PLACEHOLDER_DIGEST
        end
      end
    end
  end
end
