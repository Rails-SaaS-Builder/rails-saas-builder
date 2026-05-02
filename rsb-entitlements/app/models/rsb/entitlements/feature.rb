# frozen_string_literal: true

module RSB
  module Entitlements
    # Catalog entry for an entitlement-controlled capability.
    #
    # Three kinds:
    #   * +flag+    — boolean on/off, evaluated via {Subject#entitled_to?}
    #   * +metered+ — per-period quota (e.g., 1000 API calls / month), reset on period roll
    #   * +gauge+   — current-value cap (e.g., 5 active projects), released on resource teardown
    #
    # Lifecycle rules (TDD-019 §3, SRS-019 US-001):
    #   * +key+ and +kind+ are immutable after creation (+attr_readonly+).
    #   * Hard delete is forbidden — once a key is taken, it is taken forever.
    #     {#destroy} raises {RSB::Entitlements::HardDeleteForbidden}.
    #   * Archive is soft via +archived_at+. While archived, no field other than
    #     +archived_at+ may change; +update!+ raises +ActiveRecord::RecordInvalid+.
    #   * Setting +archived_at+ from +nil+ to a timestamp fires the
    #     +:feature_archived+ hook on the {RSB::Entitlements.hooks} registry.
    #
    # Catalog management is plain ActiveRecord — there is no service wrapper.
    class Feature < ApplicationRecord
      self.table_name = 'rsb_entitlements_features'

      KEY_FORMAT = /\A[a-z0-9_]+(\.[a-z0-9_]+)*\z/
      private_constant :KEY_FORMAT

      # :key and :kind are immutable after creation. We implement silent-drop
      # semantics (no error on update) rather than using +attr_readonly+, which
      # raises +ActiveRecord::ReadonlyAttributeError+ in Rails 7.1+.
      enum :kind, { flag: 'flag', metered: 'metered', gauge: 'gauge' }, validate: true

      validates :key, presence: true, uniqueness: true, format: { with: KEY_FORMAT }
      validates :name, presence: true
      validate :archived_record_immutable_except_unarchive, on: :update

      before_destroy :forbid_hard_delete
      after_commit :fire_archive_hook, on: %i[update]

      # @return [Boolean] true if +archived_at+ is set (currently archived)
      def archived?
        archived_at.present?
      end

      private

      IMMUTABLE_ATTRIBUTES = %w[key kind].freeze
      private_constant :IMMUTABLE_ATTRIBUTES

      # Silently drop writes to +:key+ and +:kind+ once the record is persisted.
      # We override +_write_attribute+ (the internal AR write path) rather than
      # the public +write_attribute+ because Rails 7.1+ enum setters bypass the
      # public method and call the internal one directly. Callers expect a silent
      # no-op, not +ActiveRecord::ReadonlyAttributeError+.
      #
      # @return [void]
      def _write_attribute(attr_name, value)
        return if persisted? && IMMUTABLE_ATTRIBUTES.include?(attr_name.to_s)

        super
      end

      # Validation: while a row is archived (i.e., +archived_at+ was non-nil at the
      # start of this save), reject any attribute change other than +archived_at+
      # itself. Clearing +archived_at+ to nil is the unarchive operation and is
      # allowed.
      #
      # @return [void]
      def archived_record_immutable_except_unarchive
        return unless archived_at_was.present?

        forbidden = changes.keys - %w[archived_at updated_at]
        return if forbidden.empty?

        errors.add(:base, 'cannot modify archived record (only `archived_at` may be cleared to unarchive)')
      end

      # Callback: forbids hard delete.
      #
      # @raise [RSB::Entitlements::HardDeleteForbidden] always
      def forbid_hard_delete
        raise RSB::Entitlements::HardDeleteForbidden,
              "RSB::Entitlements::Feature(#{key.inspect}) cannot be hard-deleted; archive it instead"
      end

      # Callback: fires the +:feature_archived+ hook exactly when +archived_at+
      # transitions from +nil+ to a non-nil value on an UPDATE. The +on: %i[update]+
      # filter of the +after_commit+ excludes inserts, so create-with-preset-archived_at
      # does not fire.
      #
      # @return [void]
      def fire_archive_hook
        return unless saved_change_to_archived_at?

        prior, current = saved_change_to_archived_at
        return unless prior.nil? && current.present?

        RSB::Entitlements.hooks.fire(:feature_archived, key)
      end
    end
  end
end
