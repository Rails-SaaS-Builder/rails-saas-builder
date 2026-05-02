# frozen_string_literal: true

module RSB
  module Entitlements
    # Per-subject-per-feature counter row.
    #
    # One row per `(subject_type, subject_id, feature_key)` — DB-enforced via
    # the unique index on those three columns. `period_start` is **not** part
    # of the unique key; it is mutated in place on period roll. For `gauge`
    # features, `period_start = '-infinity'` permanently (the period roll
    # never fires).
    #
    # The {Recorder} (see Task 10) is the only writer that mutates `consumed`
    # under a row-level lock. All locking goes through {.lock_or_init}, which
    # handles the first-consume race for free via `INSERT ... ON CONFLICT
    # DO NOTHING` followed by `SELECT ... FOR UPDATE`.
    class UsageCounter < ApplicationRecord
      belongs_to :feature, class_name: 'RSB::Entitlements::Feature',
                           foreign_key: :feature_key, primary_key: :key,
                           inverse_of: false

      validates :subject_type, presence: true
      validates :subject_id,   presence: true
      validates :feature_key,  presence: true

      # Atomically returns the counter row for the given key tuple, locked
      # `FOR UPDATE` for the remainder of the surrounding transaction.
      #
      # If no row exists, inserts one with `consumed = 0` and the supplied
      # `default_period_start`. Two concurrent first-time callers race
      # safely: `INSERT ... ON CONFLICT DO NOTHING` makes the loser's insert
      # a silent no-op, and both then take a row-level lock on the resulting
      # row.
      #
      # **Must be called inside an open `ActiveRecord::Base.transaction`** —
      # the row lock is released at transaction commit/rollback.
      #
      # @param subject_type [String] polymorphic owner type (e.g., `"Organization"`)
      # @param subject_id   [Integer] polymorphic owner id
      # @param feature_key  [String, Symbol] feature key (e.g., `:api_calls`)
      # @param default_period_start [Time, ActiveSupport::TimeWithZone, String]
      #   used **only** if the row is being inserted; ignored when the row
      #   already exists. Pass `'-infinity'` for gauge counters.
      # @return [RSB::Entitlements::UsageCounter] persisted row, locked FOR UPDATE
      #
      # @example First consume on a (workspace, :api_calls) tuple
      #   ActiveRecord::Base.transaction do
      #     counter = RSB::Entitlements::UsageCounter.lock_or_init(
      #       subject_type: 'Workspace', subject_id: workspace.id,
      #       feature_key:  :api_calls,
      #       default_period_start: Time.current.beginning_of_month
      #     )
      #     counter.update!(consumed: counter.consumed + 1)
      #   end
      def self.lock_or_init(subject_type:, subject_id:, feature_key:, default_period_start:)
        insert_all(
          [{
            subject_type: subject_type.to_s,
            subject_id: subject_id,
            feature_key: feature_key.to_s,
            period_start: default_period_start,
            consumed: 0,
            updated_at: Time.current
          }],
          unique_by: %i[subject_type subject_id feature_key]
        )

        where(subject_type: subject_type.to_s, subject_id: subject_id,
              feature_key: feature_key.to_s).lock.first!
      end
    end
  end
end
