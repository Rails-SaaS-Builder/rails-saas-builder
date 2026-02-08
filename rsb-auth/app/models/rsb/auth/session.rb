module RSB
  module Auth
    class Session < ApplicationRecord
      belongs_to :identity

      before_create :generate_token
      before_create :set_expiry

      after_commit :fire_created_callback, on: :create

      scope :active, -> { where("expires_at > ?", Time.current) }
      scope :expired, -> { where("expires_at <= ?", Time.current) }

      def expired?
        expires_at <= Time.current
      end

      def revoke!
        update!(expires_at: Time.current)
      end

      def touch_activity!
        update_columns(last_active_at: Time.current)
      end

      private

      def generate_token
        self.token = SecureRandom.urlsafe_base64(32)
      end

      def set_expiry
        duration = RSB::Settings.get("auth.session_duration")
        self.expires_at = Time.current + duration.to_i.seconds
      end

      def fire_created_callback
        RSB::Auth.configuration.resolve_lifecycle_handler.after_session_created(self)
      end
    end
  end
end
