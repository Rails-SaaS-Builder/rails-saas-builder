module RSB
  module Auth
    class Credential < ApplicationRecord
      belongs_to :identity
      has_many :password_reset_tokens, dependent: :destroy

      has_secure_password

      after_commit :fire_locked_callback, if: :locked_just_now?

      validates :type, presence: true
      validates :identifier, presence: true
      validate :identifier_unique_among_active, if: -> { identifier_changed? || new_record? }
      validates :password,
                length: { minimum: -> { RSB::Settings.get("auth.password_min_length") } },
                if: :password_required?

      normalizes :identifier, with: ->(v) { v.strip.downcase }
      normalizes :recovery_email, with: ->(v) { v&.strip&.downcase }

      validates :recovery_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

      scope :verified, -> { where.not(verified_at: nil) }
      scope :unverified, -> { where(verified_at: nil) }
      scope :active, -> { where(revoked_at: nil) }
      scope :revoked, -> { where.not(revoked_at: nil) }

      def verified?
        verified_at.present?
      end

      def locked?
        locked_until.present? && locked_until > Time.current
      end

      # Whether this credential has been revoked.
      #
      # @return [Boolean]
      def revoked?
        revoked_at.present?
      end

      # Revokes this credential by setting revoked_at to the current time.
      # Fires the after_credential_revoked lifecycle handler hook.
      # Does NOT delete the record (soft-delete for audit trail).
      #
      # @return [void]
      # @raise [ActiveRecord::ActiveRecordError] if the update fails
      def revoke!
        update!(revoked_at: Time.current)
        RSB::Auth.configuration.resolve_lifecycle_handler.after_credential_revoked(self)
      end

      # Restores a revoked credential by clearing revoked_at.
      # Raises CredentialConflictError if another active credential with the same
      # type and identifier already exists.
      #
      # @return [void]
      # @raise [RSB::Auth::CredentialConflictError] if an active duplicate exists
      # @raise [ActiveRecord::ActiveRecordError] if the update fails
      def restore!
        conflict = self.class.active.where(type: type, identifier: identifier).where.not(id: id).exists?
        raise RSB::Auth::CredentialConflictError if conflict

        update!(revoked_at: nil)
        RSB::Auth.configuration.resolve_lifecycle_handler.after_credential_restored(self)
      end

      def send_verification!
        self.verification_token = SecureRandom.urlsafe_base64(32)
        self.verification_sent_at = Time.current
        save!
        RSB::Auth::AuthMailer.verification(self).deliver_later if deliverable_email.present?
      end

      def verify!
        update!(verified_at: Time.current, verification_token: nil)
      end

      def verification_token_valid?
        verification_token.present? &&
          verification_sent_at.present? &&
          verification_sent_at > 24.hours.ago
      end

      # Returns the email address to use for transactional emails (verification,
      # password reset). Prefers recovery_email if present; falls back to
      # identifier only if it matches an email format (e.g., EmailPassword).
      #
      # @return [String, nil] email address, or nil if no deliverable email
      def deliverable_email
        recovery_email.presence || (identifier if identifier.match?(URI::MailTo::EMAIL_REGEXP))
      end

      private

      def password_required?
        new_record? || password.present?
      end

      def locked_just_now?
        saved_change_to_locked_until? && locked?
      end

      def fire_locked_callback
        RSB::Auth.configuration.resolve_lifecycle_handler.after_credential_locked(self)
      end

      def identifier_unique_among_active
        return if revoked_at.present? # revoked credentials don't need active-uniqueness

        scope = self.class.active.where(type: type, identifier: identifier)
        scope = scope.where.not(id: id) if persisted?
        if scope.exists?
          errors.add(:identifier, :taken)
        end
      end
    end
  end
end
