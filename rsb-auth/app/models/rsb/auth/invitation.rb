# frozen_string_literal: true

module RSB
  module Auth
    # Invitation token for gating registration. Supports multi-use tokens,
    # configurable expiry (including no-expiry), metadata, and pluggable delivery
    # via {InvitationNotifier::Base} subclasses.
    #
    # Invitations are pure tokens — delivery (email, SMS, etc.) is tracked
    # separately via {InvitationDelivery}.
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

      # @return [Boolean] true if invitation can still be used (not revoked, expired, or exhausted)
      def pending?
        !revoked? && !expired? && !exhausted?
      end

      # @return [Boolean] true when max_uses is set and uses_count has reached it
      def exhausted?
        max_uses.present? && uses_count >= max_uses
      end

      # @return [Boolean] true when expires_at is set and in the past. Nil expires_at = never expires.
      def expired?
        expires_at.present? && expires_at <= Time.current
      end

      # @return [Boolean] true when revoked_at is present
      def revoked?
        revoked_at.present?
      end

      # @return [String] computed status: 'pending', 'revoked', 'expired', or 'exhausted'
      def status
        return 'revoked' if revoked?
        return 'expired' if expired?
        return 'exhausted' if exhausted?

        'pending'
      end

      # --- State mutations ---

      # Atomically increments uses_count. Raises if invitation is not pending.
      # Uses SQL-level WHERE to prevent race conditions on concurrent use.
      #
      # @raise [RuntimeError] if invitation is no longer valid
      # @return [self] reloaded invitation
      def use!
        rows = self.class.where(id: id)
                   .where(revoked_at: nil)
                   .where('expires_at IS NULL OR expires_at > ?', Time.current)
                   .where('max_uses IS NULL OR uses_count < max_uses')
                   .update_all('uses_count = uses_count + 1')

        raise 'Invitation is no longer valid' if rows.zero?

        reload
      end

      # Soft-revokes the invitation by setting revoked_at.
      # @return [Boolean]
      def revoke!
        update!(revoked_at: Time.current)
      end

      # Returns a masked version of the token for admin display.
      # Uses {Configuration#invitation_token_masker} if set, otherwise
      # shows first 8 chars + 8 asterisks + last 4 chars.
      #
      # @return [String] masked token
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

      # Returns identities that were created using this invitation token.
      # Queries via identity metadata rather than storing IDs on the invitation
      # (avoids JSON read-modify-write race on concurrent multi-use tokens).
      #
      # @return [ActiveRecord::Relation<RSB::Auth::Identity>]
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
