# frozen_string_literal: true

module RSB
  module Auth
    class Invitation < ApplicationRecord
      # Polymorphic — works with RSB::Admin::AdminUser or any model
      belongs_to :invited_by, polymorphic: true, optional: true

      before_create :generate_token
      before_create :set_expiry

      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

      normalizes :email, with: ->(e) { e.strip.downcase }

      scope :pending, -> { where(accepted_at: nil, revoked_at: nil).where('expires_at > ?', Time.current) }
      scope :accepted, -> { where.not(accepted_at: nil) }
      scope :expired, -> { where(accepted_at: nil).where('expires_at <= ?', Time.current) }

      def pending?
        accepted_at.nil? && revoked_at.nil? && expires_at > Time.current
      end

      def accepted?
        accepted_at.present?
      end

      def expired?
        !accepted? && expires_at <= Time.current
      end

      def revoked?
        revoked_at.present?
      end

      def accept!
        update!(accepted_at: Time.current)
      end

      def revoke!
        update!(revoked_at: Time.current)
      end

      private

      def generate_token
        self.token = SecureRandom.urlsafe_base64(32)
      end

      def set_expiry
        self.expires_at = 7.days.from_now
      end
    end
  end
end
