# frozen_string_literal: true

module RSB
  module Entitlements
    # Public adapter API for subscription lifecycle. Provider adapters call
    # {sync!} from inside a webhook handler (or any other event source) to
    # idempotently project a provider-side subscription state into the local
    # `rsb_entitlements_subscriptions` table.
    #
    # @example Stripe webhook handler
    #   RSB::Entitlements::Webhooks.process(provider: 'stripe', event_id: evt.id, type: evt.type, payload: evt.to_hash) do
    #     RSB::Entitlements::Subscriptions.sync!(
    #       provider:                 'stripe',
    #       provider_subscription_id: stripe_sub.id,
    #       subject:                  workspace,
    #       plan_key:                 plan_key_from(stripe_sub),
    #       status:                   stripe_sub.status,
    #       current_period_start:     Time.at(stripe_sub.current_period_start),
    #       current_period_end:       Time.at(stripe_sub.current_period_end),
    #       trial_end:                stripe_sub.trial_end && Time.at(stripe_sub.trial_end),
    #       cancel_at_period_end:     stripe_sub.cancel_at_period_end,
    #       canceled_at:              stripe_sub.canceled_at && Time.at(stripe_sub.canceled_at),
    #       provider_customer_id:     stripe_sub.customer,
    #       raw_state:                stripe_sub.to_hash
    #     )
    #   end
    #
    # This is the *only* code path that should write to
    # `rsb_entitlements_subscriptions` from production adapter code. It:
    #
    # 1. Looks up the Plan by `plan_key` (raises {ActiveRecord::RecordNotFound}
    #    if missing).
    # 2. Validates plan-archive state **only** when `plan_key` is being set on
    #    a new row OR is changing on an existing row. Rows whose `plan_key`
    #    is unchanged continue to update freely even after the plan has been
    #    archived (per SRS US-002: "existing subscriptions on archived plan
    #    continue to resolve").
    # 3. By default (`cancel_previous_active: true`), if the new row's status
    #    is `active`/`trialing` and any *other* sub for the same subject is
    #    currently in the active set, that prior sub is auto-canceled in the
    #    same transaction (status='canceled', canceled_at=now). This makes
    #    "free → paid plan upgrade" work without the host explicitly
    #    canceling first. Pass `cancel_previous_active: false` to opt out;
    #    then a conflict raises {ActiveRecord::RecordNotUnique} as in
    #    v1.0.x.
    # 4. Performs an upsert keyed by `(provider, provider_subscription_id)`.
    # 5. On insert, honors an adapter-supplied `created_at:` so backfilled
    #    subs anchor their quota period rolls to the customer's actual
    #    provider-reported subscription start. Ignored on update.
    # 6. Saves; the DB partial unique index
    #    `(subject_type, subject_id) WHERE status IN ('active','trialing')`
    #    enforces the single-active rule as a backstop.
    # 7. On `plan_key` change for an existing row, fires `:plan_changed` with
    #    `(subscription, from_plan_key, to_plan_key)`. Hook subscribers run
    #    inside the same transaction.
    module Subscriptions
      # Upsert a subscription row.
      #
      # @example Insert new sub
      #   RSB::Entitlements::Subscriptions.sync!(
      #     provider: 'manual', provider_subscription_id: 'manual_abc',
      #     subject: workspace, plan_key: 'pro', status: 'active',
      #     current_period_start: Time.current,
      #     current_period_end:   1.month.from_now
      #   )
      #
      # @example Update existing sub (status change webhook)
      #   RSB::Entitlements::Subscriptions.sync!(
      #     provider: 'stripe', provider_subscription_id: 'sub_123',
      #     subject: workspace, plan_key: 'pro', status: 'past_due',
      #     current_period_start: Time.at(evt.current_period_start),
      #     current_period_end:   Time.at(evt.current_period_end)
      #   )
      #
      # @example Backfill an existing provider sub started months ago
      #   RSB::Entitlements::Subscriptions.sync!(
      #     provider: 'stripe', provider_subscription_id: 'sub_999',
      #     subject: workspace, plan_key: 'pro', status: 'active',
      #     current_period_start: Time.current,
      #     current_period_end:   1.month.from_now,
      #     created_at:           6.months.ago     # quota anchors to 6mo ago
      #   )
      #
      # @param provider [String, Symbol]
      # @param provider_subscription_id [String, Symbol] cross-system identity
      # @param subject [Object] any AR record acting as the subject (uses class.name + id)
      # @param plan_key [String, Symbol] FK target into `plans.key`
      # @param status [String, Symbol] one of the {Subscription} enum values
      # @param current_period_start [Time]
      # @param current_period_end [Time]
      # @param trial_end [Time, nil]
      # @param cancel_at_period_end [Boolean]
      # @param canceled_at [Time, nil]
      # @param provider_customer_id [String, nil]
      # @param raw_state [Hash] opaque provider payload
      # @param created_at [Time, nil] adapter-supplied insert anchor for quota
      #   period rolls. Honored on insert only; ignored on update.
      # @param cancel_previous_active [Boolean] when +true+ (default) and the
      #   sync is establishing this row as +active+/+trialing+, any other row
      #   for the same subject in the active set is canceled first (in the
      #   same transaction). Pass +false+ for strict mode — then a conflicting
      #   active sub raises {ActiveRecord::RecordNotUnique} as in v1.0.x.
      # @return [RSB::Entitlements::Subscription] the persisted row
      # @raise [ActiveRecord::RecordNotFound] when `plan_key` does not exist
      # @raise [ActiveRecord::RecordInvalid] when the plan is archived AND
      #   `plan_key` is being set on insert or changed on update
      # @raise [ActiveRecord::RecordNotUnique] when +cancel_previous_active+
      #   is +false+ and the partial unique index rejects a second active
      #   subscription for the same subject.
      def self.sync!(provider:, provider_subscription_id:, subject:, # rubocop:disable Metrics/ParameterLists
                     plan_key:, status:,
                     current_period_start:, current_period_end:,
                     trial_end: nil, cancel_at_period_end: false,
                     canceled_at: nil, provider_customer_id: nil,
                     raw_state: {}, created_at: nil,
                     cancel_previous_active: true)
        plan_key_str = plan_key.to_s
        status_str   = status.to_s
        plan = ::RSB::Entitlements::Plan.find_by!(key: plan_key_str)

        ::ActiveRecord::Base.transaction do
          existing = ::RSB::Entitlements::Subscription.find_by(
            provider: provider.to_s,
            provider_subscription_id: provider_subscription_id.to_s
          )
          from_plan_key     = existing&.plan_key
          from_status       = existing&.status
          plan_key_changing = existing.nil? || from_plan_key != plan_key_str

          if plan_key_changing && plan.archived_at.present?
            raise ::ActiveRecord::RecordInvalid, _subscription_with_archived_plan_error_record(plan_key_str)
          end

          if cancel_previous_active && ACTIVE_STATUSES.include?(status_str)
            _cancel_previous_active_for(subject: subject,
                                        keep_provider: provider.to_s,
                                        keep_provider_subscription_id: provider_subscription_id.to_s)
          end

          row = existing || ::RSB::Entitlements::Subscription.new
          row.assign_attributes(
            subject_type: subject.class.name,
            subject_id: subject.id,
            plan_key: plan_key_str,
            status: status_str,
            current_period_start: current_period_start,
            current_period_end: current_period_end,
            trial_end: trial_end,
            cancel_at_period_end: cancel_at_period_end,
            canceled_at: canceled_at,
            provider: provider.to_s,
            provider_subscription_id: provider_subscription_id.to_s,
            provider_customer_id: provider_customer_id,
            raw_state: raw_state
          )

          # Adapter-supplied insert anchor — backfill support per TDD §5.1.
          # Ignored on update so plan changes preserve the original anchor.
          row.created_at = created_at if existing.nil? && created_at.present?

          row.save! # raises RecordNotUnique on partial-unique-index violation

          if existing && from_plan_key != plan_key_str
            ::RSB::Entitlements.hooks.fire(:plan_changed, row, from_plan_key, plan_key_str)
          end

          # :subscription_expired fires on any (active|trialing) → expired
          # transition, regardless of whether the trigger was a provider
          # webhook, an admin action, or expire_overdue!. Hosts subscribe
          # once and get all paths uniformly.
          if status_str == 'expired' && ACTIVE_STATUSES.include?(from_status)
            ::RSB::Entitlements.hooks.fire(:subscription_expired, row, from_status)
          end

          row
        end
      end

      # Sweeps the active set for rows whose +current_period_end+ has passed
      # and transitions them to +'expired'+. Intended for hosts running a
      # cron-like job to handle subscription periods that no upstream
      # provider event will close (e.g., +provider: 'manual'+). The default
      # +providers+ scope is +%w[manual]+ — provider-driven subs should
      # close via their own webhook events, not by this sweep.
      #
      # @example Hourly cron (whenever, sidekiq-cron, k8s CronJob, etc.)
      #   RSB::Entitlements::Subscriptions.expire_overdue!
      #
      # @example Sweep multiple provider buckets
      #   RSB::Entitlements::Subscriptions.expire_overdue!(providers: %w[manual revenuecat])
      #
      # @param providers [Array<String>] which providers' rows to sweep.
      #   Defaults to +%w[manual]+ for safety.
      # @param clock [Time] the comparison clock; rows with
      #   +current_period_end <= clock+ are eligible.
      # @return [Array<RSB::Entitlements::Subscription>] the rows that were
      #   transitioned to +'expired'+ during this call. Empty array when
      #   nothing was due.
      def self.expire_overdue!(providers: %w[manual], clock: ::Time.current)
        provider_list = Array(providers).map(&:to_s)
        expired_rows = []

        ::ActiveRecord::Base.transaction do
          due = ::RSB::Entitlements::Subscription
                .where(status: ACTIVE_STATUSES, provider: provider_list)
                .where(::RSB::Entitlements::Subscription.arel_table[:current_period_end].lteq(clock))
                .lock

          due.find_each do |sub|
            from_status = sub.status
            sub.update!(status: 'expired')
            ::RSB::Entitlements.hooks.fire(:subscription_expired, sub, from_status)
            expired_rows << sub
          end
        end

        expired_rows
      end

      # Statuses that count as "actively granting entitlements" — also the set
      # the partial unique index protects.
      ACTIVE_STATUSES = %w[active trialing].freeze
      private_constant :ACTIVE_STATUSES

      # Cancels any other +active+/+trialing+ row for the same subject before
      # we UPSERT a new one. Excludes the row we are about to write (matched
      # by +(provider, provider_subscription_id)+) so a re-sync of the same
      # row doesn't cancel itself.
      #
      # Locks the rows it finds (FOR UPDATE) so concurrent syncs serialize
      # cleanly: the second sync will block until the first commits, then
      # see the previously-active row already canceled.
      #
      # @api private
      def self._cancel_previous_active_for(subject:, keep_provider:, keep_provider_subscription_id:)
        prev_rows = ::RSB::Entitlements::Subscription
                    .where(subject_type: subject.class.name, subject_id: subject.id, status: ACTIVE_STATUSES)
                    .where.not(provider: keep_provider, provider_subscription_id: keep_provider_subscription_id)
                    .lock
        now = ::Time.current
        prev_rows.find_each do |prev|
          prev.update!(status: 'canceled', canceled_at: now)
        end
      end

      # Builds a stub Subscription record carrying a "plan archived" error so
      # `ActiveRecord::RecordInvalid.new(record)` produces a familiar AR error
      # shape. The record is never persisted.
      #
      # @api private
      def self._subscription_with_archived_plan_error_record(plan_key_str)
        ::RSB::Entitlements::Subscription.new(plan_key: plan_key_str).tap do |stub|
          stub.errors.add(:plan_key, "plan #{plan_key_str.inspect} is archived")
        end
      end
    end
  end
end
