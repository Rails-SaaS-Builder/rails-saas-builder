# frozen_string_literal: true

module RSB
  module Auth
    class Invitation < ApplicationRecord
      self.table_name = 'rsb_auth_invitations'

      belongs_to :invited_by, polymorphic: true, optional: true
      has_many :deliveries, class_name: 'RSB::Auth::InvitationDelivery',
                            foreign_key: :invitation_id, dependent: :destroy

      before_create :generate_token
      before_create :set_expiry

      # --- Scopes ---

      scope :pending, lambda {
        where(revoked_at: nil)
          .where('expires_at IS NULL OR expires_at > ?', Time.current)
          .where('max_uses IS NULL OR uses_count < max_uses')
      }

      scope :exhausted, lambda {
        where.not(max_uses: nil)
             .where('uses_count >= max_uses')
      }

      scope :expired, lambda {
        where(revoked_at: nil)
          .where.not(expires_at: nil)
          .where('expires_at <= ?', Time.current)
      }

      scope :revoked, lambda {
        where.not(revoked_at: nil)
      }

      # --- Predicates ---

      def pending?
        !revoked? && !expired? && !exhausted?
      end

      def exhausted?
        max_uses.present? && uses_count >= max_uses
      end

      def expired?
        expires_at.present? && expires_at <= Time.current
      end

      def revoked?
        revoked_at.present?
      end

      def status
        return 'revoked' if revoked?
        return 'expired' if expired?
        return 'exhausted' if exhausted?

        'pending'
      end

      # --- State mutations ---

      def use!
        rows = self.class.where(id: id)
                   .where(revoked_at: nil)
                   .where('expires_at IS NULL OR expires_at > ?', Time.current)
                   .where('max_uses IS NULL OR uses_count < max_uses')
                   .update_all('uses_count = uses_count + 1')

        raise 'Invitation is no longer valid' if rows.zero?

        reload
      end

      def revoke!
        update!(revoked_at: Time.current)
      end

      # Returns a masked version of the token for display.
      # Uses the configured masker or a default that shows first 8 + asterisks + last 4.
      def masked_token
        masker = RSB::Auth.configuration.invitation_token_masker
        if masker
          masker.call(token)
        else
          "#{token[0..7]}#{'*' * 8}#{token[-4..]}"
        end
      end

      # Formatted usage string for admin display: "3 / 10" or "3 / ∞"
      # @return [String]
      def uses
        limit = max_uses.nil? ? "\u221E" : max_uses.to_s
        "#{uses_count} / #{limit}"
      end

      # --- Convenience ---

      def registered_identities
        RSB::Auth::Identity.where("CAST(metadata->>'invitation_id' AS TEXT) = ?", id.to_s)
      end

      def expires_at=(value)
        @expires_at_explicitly_set = true
        super
      end

      private

      def generate_token
        self.token ||= custom_token || SecureRandom.urlsafe_base64(32)
      end

      def custom_token
        return unless RSB::Auth.configuration.respond_to?(:invitation_token_generator)

        generator = RSB::Auth.configuration.invitation_token_generator
        generator&.call
      end

      def set_expiry
        return if @expires_at_explicitly_set

        self.expires_at ||= 7.days.from_now
      end
    end
  end
end
