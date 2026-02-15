# frozen_string_literal: true

module RSB
  module Entitlements
    class PaymentRequest < ApplicationRecord
      STATUSES = %w[pending processing approved rejected expired refunded].freeze
      ACTIONABLE_STATUSES = %w[pending processing].freeze

      belongs_to :requestable, polymorphic: true
      belongs_to :plan
      belongs_to :entitlement, optional: true

      validates :provider_key, presence: true,
                               inclusion: {
                                 in: ->(_) { RSB::Entitlements.providers.keys.map(&:to_s) },
                                 message: 'is not a registered provider'
                               }
      validates :status, presence: true, inclusion: { in: STATUSES }
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
      validates :currency, presence: true

      scope :actionable, -> { where(status: ACTIONABLE_STATUSES) }
      scope :for_provider, ->(key) { where(provider_key: key.to_s) }

      after_commit :fire_changed_callback, if: :saved_change_to_status?

      # @return [Boolean] true if status is "pending"
      def pending?
        status == 'pending'
      end

      # @return [Boolean] true if status is "processing"
      def processing?
        status == 'processing'
      end

      # @return [Boolean] true if status is "approved"
      def approved?
        status == 'approved'
      end

      # @return [Boolean] true if status is "rejected"
      def rejected?
        status == 'rejected'
      end

      # @return [Boolean] true if status is "expired"
      def expired?
        status == 'expired'
      end

      # @return [Boolean] true if status is "refunded"
      def refunded?
        status == 'refunded'
      end

      # @return [Boolean] true if status is "pending" or "processing"
      def actionable?
        ACTIONABLE_STATUSES.include?(status)
      end

      private

      def fire_changed_callback
        callback = RSB::Entitlements.configuration.after_payment_request_changed
        callback&.call(self)
      end
    end
  end
end
