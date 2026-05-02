# frozen_string_literal: true

module RSB
  module Entitlements
    # Mutable composition: the row that says "plan X grants feature Y with
    # shape Z". Unlike {Feature} and {Plan}, PlanFeature is **not** a catalog
    # primitive — `update!` is permitted, hard-delete is permitted, no
    # `attr_readonly` columns. The two business rules are enforced via
    # validations:
    #
    # 1. {referenced_records_not_archived}: neither the referenced Plan nor the
    #    referenced Feature may be archived. `create!` and `update!` raise
    #    `ActiveRecord::RecordInvalid` if either is archived.
    #
    # 2. {grant_shape}: the `(feature.kind, period)` combination must be
    #    coherent.
    #    - `flag`: `enabled` may be `true` / `false` / `nil`. `period` and
    #      `limit_value` are not validated (resolver ignores them for flags).
    #    - `metered`: `period` is required and must be one of
    #      `%w[day week month year]`. `limit_value` is optional (nil = unlimited).
    #      `enabled` is irrelevant.
    #    - `gauge`: `period` must be `nil` (gauge has no period concept).
    #      `limit_value` is optional (nil = unlimited).
    #
    # Destroying a PlanFeature does not touch the existing `usage_counters`
    # rows for the (subject, feature) pair. Those rows go stale-but-harmless
    # and are no longer drained. Counter cleanup is out of scope for v1.
    #
    # @example Register-if-missing (deploy-safe)
    #   RSB::Entitlements::PlanFeature.find_or_create_by!(
    #     plan_key: 'pro', feature_key: 'api_calls'
    #   ) do |pf|
    #     pf.assign_attributes(limit_value: 10_000, period: 'month')
    #   end
    #
    # @example Detach a grant
    #   RSB::Entitlements::PlanFeature
    #     .find_by(plan_key: 'pro', feature_key: 'api_calls')
    #     &.destroy
    class PlanFeature < ApplicationRecord
      VALID_PERIODS = %w[day week month year].freeze

      belongs_to :plan,    foreign_key: :plan_key,    primary_key: :key
      belongs_to :feature, foreign_key: :feature_key, primary_key: :key

      validates :plan_key,    presence: true,
                              uniqueness: { scope: :feature_key }
      validates :feature_key, presence: true

      before_validation :nullify_blank_period

      validate :referenced_records_not_archived
      validate :grant_shape

      private

      def nullify_blank_period
        self.period = nil if period.is_a?(String) && period.empty?
      end

      # Both referenced records must be unarchived. The associations are reset
      # before reading so that a plan or feature archived between the last load
      # and the current save is always detected — stale identity-map entries
      # would otherwise allow invalid rows through on update.
      #
      # @return [void]
      def referenced_records_not_archived
        association(:plan).reset
        association(:feature).reset
        errors.add(:plan_key,    'is archived') if plan&.archived_at
        errors.add(:feature_key, 'is archived') if feature&.archived_at
      end

      # Enforces the (feature.kind, period) coherence rules. Skips silently
      # if `feature` is missing — the presence validation on `feature_key`
      # plus FK constraints surface that case with the standard error message.
      #
      # @return [void]
      def grant_shape
        case feature&.kind
        when 'flag'
          # Flags ignore period and limit_value. No validation forces nil on
          # those columns; resolver simply does not read them. Caller may set
          # enabled true/false/nil.
          nil
        when 'metered'
          if period.blank?
            errors.add(:period, "can't be blank for metered features")
          elsif !VALID_PERIODS.include?(period)
            errors.add(:period, "is not included in #{VALID_PERIODS.inspect}")
          end
        when 'gauge'
          errors.add(:period, 'must be blank for gauge features') if period.present?
        end
      end
    end
  end
end
