module RSB
  module Auth
    class PasswordResetToken < ApplicationRecord
      belongs_to :credential

      before_create :generate_token
      before_create :set_expiry

      scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

      def expired?
        expires_at <= Time.current
      end

      def used?
        used_at.present?
      end

      def use!
        update!(used_at: Time.current)
      end

      private

      def generate_token
        self.token = SecureRandom.urlsafe_base64(32)
      end

      def set_expiry
        self.expires_at = 2.hours.from_now
      end
    end
  end
end
