# frozen_string_literal: true

require 'rsb/entitlements/errors'

module RSB
  module Entitlements
    # Flat plan catalog entry. v1 has no kind/is_default/independent/priority.
    #
    # Lifecycle rules (per SRS-019 US-002 / TDD-019 §3):
    #   - +key+ is immutable after creation (silent-drop semantics; no exception on write).
    #   - Hard delete is forbidden (before_destroy raises HardDeleteForbidden).
    #   - Archived plans are immutable except for unarchiving (validation).
    #   - Archive transition (null -> timestamp) fires the :plan_archived hook.
    #
    # TODO: this model shares ~80% of its archive/hard-delete/hook code with Feature.
    # If a third archivable model appears in this gem, extract these concerns into
    # `RSB::Entitlements::Concerns::SoftArchive` (validate + before_destroy + after_commit).
    # Until then, keep the duplication explicit — premature abstraction is worse than DRY-violation.
    class Plan < ApplicationRecord
      self.table_name = 'rsb_entitlements_plans'

      # +key+ is immutable after creation. We override +_write_attribute+ for silent-drop
      # semantics rather than using +attr_readonly+, which raises
      # +ActiveRecord::ReadonlyAttributeError+ in Rails 7.1+.
      IMMUTABLE_ATTRIBUTES = %w[key].freeze
      private_constant :IMMUTABLE_ATTRIBUTES

      validates :key,  presence: true, uniqueness: true
      validates :name, presence: true

      validate :archived_record_immutable_except_unarchive, on: :update

      before_destroy :forbid_hard_delete
      after_commit   :fire_plan_archived_hook, on: %i[create update]

      # @return [Boolean] true if archived_at is present
      def archived?
        archived_at.present?
      end

      private

      # Silently drop writes to +:key+ once the record is persisted.
      # We override +_write_attribute+ (the internal AR write path) so that
      # callers see a silent no-op rather than +ActiveRecord::ReadonlyAttributeError+.
      #
      # @return [void]
      def _write_attribute(attr_name, value)
        return if persisted? && IMMUTABLE_ATTRIBUTES.include?(attr_name.to_s)

        super
      end

      # Enforces that an archived row may only be updated by setting `archived_at`
      # back to nil (unarchive). Any other column change while archived is rejected.
      #
      # Run as a standard AR validation so update! raises RecordInvalid (no custom error class).
      def archived_record_immutable_except_unarchive
        return unless archived_at_was.present?
        return if archived_at.nil? # unarchiving is the one allowed transition

        # Any change other than archived_at while archived is rejected.
        forbidden_changes = changes.keys - %w[archived_at updated_at]
        return if forbidden_changes.empty?

        errors.add(:base, 'cannot modify archived plan (unarchive first by setting archived_at: nil)')
      end

      # Raises HardDeleteForbidden — plans are append-only; once a key is taken
      # it is taken forever. Soft-archive via `archived_at` is the only way out.
      def forbid_hard_delete
        raise RSB::Entitlements::HardDeleteForbidden,
              "Plan #{key.inspect} cannot be hard-deleted; set archived_at instead"
      end

      # Fires :plan_archived only on a null -> present transition of archived_at
      # within a single transaction. Skipped on create (no "transition") and on
      # unarchive (present -> nil) and on present -> present updates.
      def fire_plan_archived_hook
        return unless saved_change_to_archived_at?

        prior, current = saved_change_to_archived_at
        return unless prior.nil? && current.present?
        return if previously_new_record? # initial create with archived_at set is not a transition

        RSB::Entitlements.hooks.fire(:plan_archived, key)
      end
    end
  end
end
