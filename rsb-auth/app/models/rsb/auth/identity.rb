# frozen_string_literal: true

module RSB
  module Auth
    class Identity < ApplicationRecord
      has_many :credentials, dependent: :destroy
      has_many :sessions, dependent: :destroy

      enum :status, { active: 'active', suspended: 'suspended', deactivated: 'deactivated', deleted: 'deleted' }

      # NOTE: the `active` scope is already defined by the enum above

      after_commit :fire_created_callback, on: :create

      # Returns the first active credential by creation date.
      # A revoked credential is never primary.
      #
      # @return [RSB::Auth::Credential, nil]
      def primary_credential
        credentials.active.order(:created_at).first
      end

      def primary_identifier
        primary_credential&.identifier
      end

      # Returns only active (non-revoked) credentials.
      #
      # @return [ActiveRecord::Relation<RSB::Auth::Credential>]
      def active_credentials
        credentials.active
      end

      # Whether this identity has completed all required profile information.
      #
      # Returns +true+ by default. Override via an identity concern to check
      # for required fields (e.g., profile presence, metadata completeness).
      #
      # @return [Boolean]
      #
      # @example Default behavior
      #   identity = RSB::Auth::Identity.create!
      #   identity.complete? # => true
      #
      # @example With a concern that checks metadata
      #   # In concern:
      #   def complete?
      #     metadata["first_name"].present?
      #   end
      #
      def complete?
        true
      end

      private

      def fire_created_callback
        RSB::Auth.configuration.resolve_lifecycle_handler.after_identity_created(self)
      end
    end
  end
end
