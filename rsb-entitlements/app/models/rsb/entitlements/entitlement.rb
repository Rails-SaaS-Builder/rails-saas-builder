module RSB
  module Entitlements
    class Entitlement < ApplicationRecord
      STATUSES = %w[pending active expired revoked].freeze
      REVOKE_REASONS = %w[refund admin chargeback non_renewal upgrade].freeze

      belongs_to :entitleable, polymorphic: true
      belongs_to :plan

      validates :status, presence: true, inclusion: { in: STATUSES }
      validates :provider, presence: true,
                           inclusion: {
                             in: ->(_) { RSB::Entitlements.providers.keys.map(&:to_s) },
                             message: "is not a registered provider"
                           }
      validates :revoke_reason, inclusion: { in: REVOKE_REASONS }, allow_nil: true

      scope :active, -> { where(status: "active") }
      scope :current, -> { where(status: %w[pending active]) }

      after_commit :fire_changed_callback, if: :saved_change_to_status?
      after_commit :create_usage_counters, on: [:create, :update], if: :active?

      def activate!
        update!(status: "active", activated_at: Time.current)
      end

      def expire!
        update!(status: "expired")
      end

      def revoke!(reason:)
        update!(status: "revoked", revoked_at: Time.current, revoke_reason: reason)
      end

      def active?
        status == "active"
      end

      def expired?
        status == "expired"
      end

      def revoked?
        status == "revoked"
      end

      def pending?
        status == "pending"
      end

      private

      def fire_changed_callback
        callback = RSB::Entitlements.configuration.after_entitlement_changed
        callback&.call(self)
      end

      def create_usage_counters
        return unless saved_change_to_status? && status == "active"
        UsageCounterService.new.create_counters_for(self)
      end
    end
  end
end
