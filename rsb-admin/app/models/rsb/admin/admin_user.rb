# frozen_string_literal: true

module RSB
  module Admin
    class AdminUser < ApplicationRecord
      has_secure_password

      encrypts :otp_secret
      encrypts :otp_backup_codes

      belongs_to :role, optional: true
      has_many :admin_sessions, dependent: :destroy

      validates :email, presence: true,
                        uniqueness: { case_sensitive: false },
                        format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :password, length: { minimum: 8 }, if: :password_required?
      validate :pending_email_uniqueness, if: -> { pending_email.present? }

      normalizes :email, with: ->(e) { e.strip.downcase }

      def record_sign_in!(ip:)
        update_columns(last_sign_in_at: Time.current, last_sign_in_ip: ip)
      end

      def can?(resource, action)
        return false unless role # no role = no access

        role.can?(resource, action)
      end

      # Initiates email verification by storing the new email as pending
      # and generating a verification token.
      #
      # @param new_email [String] the new email address to verify
      # @return [void]
      # @raise [ActiveRecord::RecordInvalid] if pending_email fails validation
      def generate_email_verification!(new_email)
        update!(
          pending_email: new_email.strip.downcase,
          email_verification_token: SecureRandom.urlsafe_base64(32),
          email_verification_sent_at: Time.current
        )
      end

      # Confirms the pending email change by moving pending_email to email
      # and clearing all verification fields.
      #
      # @return [void]
      # @raise [ActiveRecord::RecordInvalid] if the email update fails
      def verify_email!
        update!(
          email: pending_email,
          pending_email: nil,
          email_verification_token: nil,
          email_verification_sent_at: nil
        )
      end

      # @return [Boolean] true if there is a pending email awaiting verification
      def email_verification_pending?
        pending_email.present?
      end

      # @return [Boolean] true if the verification token has expired
      def email_verification_expired?
        return true unless email_verification_sent_at

        email_verification_sent_at < RSB::Admin.configuration.email_verification_expiry.ago
      end

      # @return [Boolean] true if TOTP 2FA is fully enabled
      def otp_enabled?
        otp_secret.present? && otp_required?
      end

      # Generates a new TOTP secret. Does NOT save to database —
      # the secret is returned for QR code display during enrollment.
      #
      # @return [String] base32-encoded TOTP secret
      def generate_otp_secret!
        ROTP::Base32.random
      end

      # Verifies a TOTP code against the stored secret.
      #
      # @param code [String] 6-digit TOTP code
      # @return [Boolean] true if code is valid (with 30s drift tolerance)
      def verify_otp(code)
        return false unless otp_secret.present?

        totp = ROTP::TOTP.new(otp_secret)
        totp.verify(code.to_s, drift_behind: 30, drift_ahead: 30).present?
      end

      # Generates 10 one-time backup codes. Stores bcrypt hashes in the
      # database. Returns the plaintext codes for one-time display.
      #
      # @return [Array<String>] 10 plaintext backup codes (8 alphanumeric chars each)
      def generate_backup_codes!
        codes = 10.times.map { SecureRandom.alphanumeric(8) }
        hashes = codes.map { |code| BCrypt::Password.create(code) }
        update!(otp_backup_codes: hashes.to_json)
        codes
      end

      # Verifies a backup code against stored hashes. If valid, the
      # matching hash is removed (consumed) and the array is saved.
      #
      # @param code [String] plaintext backup code
      # @return [Boolean] true if code matched and was consumed
      def verify_backup_code(code)
        return false unless otp_backup_codes.present?

        stored = JSON.parse(otp_backup_codes)
        matched_index = stored.index { |hash| BCrypt::Password.new(hash) == code }
        return false unless matched_index

        stored.delete_at(matched_index)
        update!(otp_backup_codes: stored.to_json)
        true
      end

      # Disables TOTP 2FA by clearing all OTP fields.
      #
      # @return [void]
      def disable_otp!
        update!(otp_secret: nil, otp_required: false, otp_backup_codes: nil)
      end

      # Builds the otpauth:// URI for QR code generation.
      #
      # @param secret [String] base32-encoded TOTP secret
      # @param issuer [String] application name for authenticator app display
      # @return [String] otpauth:// URI
      def otp_provisioning_uri(secret, issuer: "RSB Admin")
        ROTP::TOTP.new(secret, issuer: issuer).provisioning_uri(email)
      end

      private

      def password_required?
        new_record? || password.present?
      end

      def pending_email_uniqueness
        return unless self.class.where.not(id: id).exists?(email: pending_email)

        errors.add(:pending_email, 'has already been taken')
      end
    end
  end
end
