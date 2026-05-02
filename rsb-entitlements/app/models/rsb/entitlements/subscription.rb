# frozen_string_literal: true

module RSB
  module Entitlements
    # Represents a single (provider, provider_subscription_id) tuple — the
    # row-shaped record of a subject's relationship with a Plan as reported by
    # an external billing provider (or `manual` for hosts that don't use one).
    #
    # v1 is **flat plans only**. Each subject has at most one subscription in
    # `active` or `trialing` status — DB-enforced via a partial unique index:
    #
    #   CREATE UNIQUE INDEX ON rsb_entitlements_subscriptions
    #     (subject_type, subject_id) WHERE status IN ('active','trialing');
    #
    # Adapters that violate this (e.g. by syncing a new active sub before
    # canceling the old one) see {ActiveRecord::RecordNotUnique} bubble up
    # from `save!`. Reconciliation is the adapter's responsibility — typically
    # cancel-old-then-create-new in a single transaction (see TDD §5.6).
    #
    # `subject_type` / `subject_id` is opaque polymorphic storage. The gem
    # never validates that `subject_type` resolves to a real class.
    #
    # `raw_state` is opaque jsonb storage for provider payloads — the gem
    # never parses it. Adapters use it for diagnostics and replay.
    #
    # Most lifecycle logic (idempotent upsert, plan-archive guard, hook
    # firing on plan change) lives in {RSB::Entitlements::Subscriptions.sync!}.
    # This model is intentionally thin.
    class Subscription < ApplicationRecord
      ACTIVE_STATUSES = %w[active trialing].freeze

      belongs_to :plan, class_name: 'RSB::Entitlements::Plan',
                        foreign_key: :plan_key, primary_key: :key, inverse_of: false

      # Closed enum — values come from the DB CHECK constraint.
      # Omitting `validate: true` so that assignment of an unknown value raises
      # `ArgumentError` immediately (adapter contract). A nil/unset status is
      # caught by the explicit `validates :status, presence: true` below.
      enum :status, {
        incomplete: 'incomplete',
        trialing: 'trialing',
        active: 'active',
        past_due: 'past_due',
        canceled: 'canceled',
        expired: 'expired'
      }

      validates :subject_type,             presence: true
      validates :subject_id,               presence: true
      validates :plan_key,                 presence: true
      validates :status,                   presence: true
      validates :current_period_start,     presence: true
      validates :current_period_end,       presence: true
      validates :provider,                 presence: true
      validates :provider_subscription_id, presence: true
      validates :provider_subscription_id, uniqueness: { scope: :provider }

      # Subscriptions whose grants currently apply.
      #
      # @return [ActiveRecord::Relation<Subscription>]
      scope :active_or_trialing, -> { where(status: ACTIVE_STATUSES) }

      # Narrow to a single polymorphic subject. Accepts the column pair
      # directly — callers may pass a subject record's `class.name` / `id`
      # or any opaque type/id pair.
      #
      # @param subject_type [String]
      # @param subject_id [Integer]
      # @return [ActiveRecord::Relation<Subscription>]
      scope :for_subject, lambda { |subject_type:, subject_id:|
        where(subject_type: subject_type, subject_id: subject_id)
      }
    end
  end
end
