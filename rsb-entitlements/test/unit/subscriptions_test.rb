# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class SubscriptionsTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        @plan_free = Plan.create!(key: 'free', name: 'Free')
        @plan_pro  = Plan.create!(key: 'pro',  name: 'Pro')
        @workspace = Organization.create!(name: 'Acme')
        @other     = Organization.create!(name: 'Globex')
      end

      def base_args(plan_key: 'pro', psid: 'sub_1', status: 'active', subject: @workspace, **extras)
        {
          provider: 'manual',
          provider_subscription_id: psid,
          subject: subject,
          plan_key: plan_key,
          status: status,
          current_period_start: Time.current,
          current_period_end: 1.month.from_now,
          raw_state: {}
        }.merge(extras)
      end

      def call(**args)
        Subscriptions.sync!(**base_args(**args))
      end

      # =====================================================================
      # Insert path
      # =====================================================================

      test 'sync! creates a new row with the provided fields when none exists' do
        sub = call(plan_key: 'pro', psid: 'sub_1', status: 'active')

        assert_predicate sub, :persisted?
        assert_equal 'pro',                       sub.plan_key
        assert_equal 'active',                    sub.status
        assert_equal 'manual',                    sub.provider
        assert_equal 'sub_1',                     sub.provider_subscription_id
        assert_equal @workspace.id,               sub.subject_id
        assert_equal @workspace.class.name,       sub.subject_type
        assert_equal({}, sub.raw_state)
      end

      test 'sync! returns the persisted Subscription record' do
        sub = call(psid: 'sub_2')
        assert_kind_of RSB::Entitlements::Subscription, sub
        assert_predicate sub, :persisted?
      end

      test 'sync! raises ActiveRecord::RecordNotFound when plan_key is unknown' do
        assert_raises(ActiveRecord::RecordNotFound) do
          call(plan_key: 'nonexistent', psid: 'sub_x')
        end
      end

      # =====================================================================
      # Update path — same (provider, provider_subscription_id)
      # =====================================================================

      test 'sync! updates the existing row keyed by (provider, provider_subscription_id)' do
        first  = call(plan_key: 'pro', psid: 'sub_1', status: 'trialing')
        second = call(
          plan_key: 'pro',
          psid: 'sub_1',
          status: 'active',
          current_period_end: 2.months.from_now,
          raw_state: { 'evt' => 'updated' }
        )

        assert_equal first.id, second.id
        assert_equal 'active',               second.reload.status
        assert_equal({ 'evt' => 'updated' }, second.raw_state)
        assert_in_delta 2.months.from_now.to_i, second.current_period_end.to_i, 5
      end

      test 'sync! preserves id when updating an existing row' do
        first = call(psid: 'sub_1', status: 'trialing')
        original_id = first.id

        second = call(psid: 'sub_1', status: 'active')
        assert_equal original_id, second.id
      end

      # =====================================================================
      # :plan_changed hook
      # =====================================================================

      test ':plan_changed fires when plan_key changes on an existing row' do
        captured = []
        RSB::Entitlements.on(:plan_changed) do |sub, from, to|
          captured << [sub.id, from, to]
        end

        first = call(plan_key: 'pro', psid: 'sub_1')
        call(plan_key: 'free', psid: 'sub_1')

        assert_equal 1,         captured.size
        assert_equal first.id,  captured.first[0]
        assert_equal 'pro',     captured.first[1]
        assert_equal 'free',    captured.first[2]
      end

      test ':plan_changed does NOT fire on insert (no prior row)' do
        captured = []
        RSB::Entitlements.on(:plan_changed) { |*_args| captured << :fired }
        call(plan_key: 'pro', psid: 'sub_1')
        assert_empty captured
      end

      test ':plan_changed does NOT fire on update when plan_key is unchanged' do
        captured = []
        RSB::Entitlements.on(:plan_changed) { |*_args| captured << :fired }
        call(plan_key: 'pro', psid: 'sub_1', status: 'trialing')
        call(plan_key: 'pro', psid: 'sub_1', status: 'active')
        assert_empty captured
      end

      # =====================================================================
      # Plan-archive validation — timing per SRS US-002
      # =====================================================================

      test 'sync! raises RecordInvalid when inserting against an archived plan' do
        @plan_pro.update!(archived_at: Time.current)
        assert_raises(ActiveRecord::RecordInvalid) do
          call(plan_key: 'pro', psid: 'sub_archived_insert')
        end
      end

      test 'sync! raises RecordInvalid when changing plan_key on existing row to an archived plan' do
        # Create the row with a non-archived plan first.
        call(plan_key: 'pro', psid: 'sub_1')

        # Archive `free`, then try to change the existing sub's plan_key to it.
        @plan_free.update!(archived_at: Time.current)

        assert_raises(ActiveRecord::RecordInvalid) do
          call(plan_key: 'free', psid: 'sub_1')
        end
      end

      # The key v1 behavior: existing subscriptions on archived plans
      # continue to receive lifecycle updates. Only plan_key-set/change
      # triggers archive validation. (SRS US-002.)
      test 'sync! succeeds when updating existing row whose plan was archived AFTER creation, plan_key unchanged' do
        # Create the row while the plan is still active.
        first = call(
          plan_key: 'pro',
          psid: 'sub_1',
          status: 'active',
          current_period_end: 1.month.from_now
        )

        # Plan gets archived (sunsetted) by the host.
        @plan_pro.update!(archived_at: Time.current)

        # A subsequent webhook must still go through — provider lifecycle
        # events for existing subs on a sunsetted plan are not blocked.
        new_period_end = 2.months.from_now
        updated = call(
          plan_key: 'pro',
          psid: 'sub_1',
          status: 'past_due',
          current_period_end: new_period_end
        )

        assert_equal first.id,        updated.id
        assert_equal 'past_due',      updated.reload.status
        assert_in_delta new_period_end.to_i, updated.current_period_end.to_i, 5
      end

      # =====================================================================
      # Partial unique index — one active subscription per subject
      # =====================================================================

      # =====================================================================
      # cancel_previous_active — auto-cancel prior sub when a new active one
      # comes in for the same subject (default behavior in v1.1+).
      # =====================================================================

      test 'sync! auto-cancels the prior active sub when a new active one is synced (default)' do
        first = call(plan_key: 'free', psid: 'sub_free', status: 'active')

        second = call(plan_key: 'pro', psid: 'sub_pro', status: 'active')

        assert_equal 'canceled', first.reload.status
        assert_not_nil first.canceled_at
        assert_equal 'active', second.status
        assert_equal 1,
                     Subscription.where(
                       subject_type: @workspace.class.name,
                       subject_id: @workspace.id,
                       status: 'active'
                     ).count
      end

      test 'sync! auto-cancels prior trialing sub when a new active sub arrives' do
        trialing = call(plan_key: 'free', psid: 'sub_t', status: 'trialing')

        call(plan_key: 'pro', psid: 'sub_pro', status: 'active')

        assert_equal 'canceled', trialing.reload.status
      end

      test 'sync! does NOT auto-cancel when the new sub is non-active (canceled/incomplete/etc.)' do
        first = call(plan_key: 'free', psid: 'sub_free', status: 'active')

        # Inserting a canceled-from-the-start row should not disturb the active sub.
        call(plan_key: 'pro', psid: 'sub_pro', status: 'canceled')

        assert_equal 'active', first.reload.status
      end

      test 'sync! does NOT cancel itself when re-syncing the same (provider, provider_subscription_id) row' do
        first = call(plan_key: 'pro', psid: 'sub_pro', status: 'active')

        # Re-sync the same row with no changes — must not flip itself to canceled.
        result = call(plan_key: 'pro', psid: 'sub_pro', status: 'active')

        assert_equal first.id, result.id
        assert_equal 'active', result.status
      end

      test 'sync! does NOT cross-cancel between different subjects' do
        sub_acme = call(plan_key: 'pro', psid: 'sub_acme', status: 'active', subject: @workspace)

        call(plan_key: 'pro', psid: 'sub_globex', status: 'active', subject: @other)

        assert_equal 'active', sub_acme.reload.status, 'Acme sub must remain active when Globex gets a new sub'
      end

      test 'sync! with cancel_previous_active: false preserves v1.0.x strict semantics (RecordNotUnique)' do
        call(plan_key: 'free', psid: 'sub_free', status: 'active')

        assert_raises(ActiveRecord::RecordNotUnique) do
          call(plan_key: 'pro', psid: 'sub_pro', status: 'active', cancel_previous_active: false)
        end
      end

      # =====================================================================
      # :subscription_expired hook (fires on (active|trialing) → expired)
      # =====================================================================

      test ':subscription_expired fires when sync! transitions an active row to expired' do
        sub = call(plan_key: 'pro', psid: 'sub_pro', status: 'active')
        captured = []
        RSB::Entitlements.on(:subscription_expired) { |row, from| captured << [row.id, from] }

        call(plan_key: 'pro', psid: 'sub_pro', status: 'expired')

        assert_equal 1, captured.size
        assert_equal sub.id, captured.first[0]
        assert_equal 'active', captured.first[1]
      end

      test ':subscription_expired fires when sync! transitions a trialing row to expired' do
        call(plan_key: 'pro', psid: 'sub_t', status: 'trialing')
        captured = []
        RSB::Entitlements.on(:subscription_expired) { |_row, from| captured << from }

        call(plan_key: 'pro', psid: 'sub_t', status: 'expired')

        assert_equal ['trialing'], captured
      end

      test ':subscription_expired does NOT fire when transitioning from a non-active state to expired' do
        call(plan_key: 'pro', psid: 'sub_c', status: 'canceled')
        captured = []
        RSB::Entitlements.on(:subscription_expired) { |*_args| captured << :fired }

        call(plan_key: 'pro', psid: 'sub_c', status: 'expired')

        assert_empty captured
      end

      test ':subscription_expired does NOT fire on insert directly into expired (no prior row)' do
        captured = []
        RSB::Entitlements.on(:subscription_expired) { |*_args| captured << :fired }

        call(plan_key: 'pro', psid: 'sub_new', status: 'expired')

        assert_empty captured
      end

      # =====================================================================
      # expire_overdue! — sweep manual subs whose current_period_end has passed
      # =====================================================================

      test 'expire_overdue! transitions overdue manual subs to expired' do
        sub = call(plan_key: 'pro', psid: 'sub_manual', status: 'active',
                   current_period_end: 1.day.ago)

        rows = Subscriptions.expire_overdue!

        assert_equal [sub.id], rows.map(&:id)
        assert_equal 'expired', sub.reload.status
      end

      test 'expire_overdue! transitions overdue trialing subs to expired' do
        sub = call(plan_key: 'pro', psid: 'sub_trial', status: 'trialing',
                   current_period_end: 1.hour.ago)

        Subscriptions.expire_overdue!

        assert_equal 'expired', sub.reload.status
      end

      test 'expire_overdue! does NOT touch subs whose current_period_end is in the future' do
        sub = call(plan_key: 'pro', psid: 'sub_future', status: 'active',
                   current_period_end: 1.day.from_now)

        rows = Subscriptions.expire_overdue!

        assert_empty rows
        assert_equal 'active', sub.reload.status
      end

      test 'expire_overdue! does NOT touch already-canceled or already-expired rows' do
        canceled = call(plan_key: 'pro', psid: 'sub_canceled', status: 'canceled',
                        current_period_end: 1.day.ago)
        expired  = call(plan_key: 'pro', psid: 'sub_expired',  status: 'expired',
                        current_period_end: 1.day.ago)

        rows = Subscriptions.expire_overdue!

        assert_empty rows
        assert_equal 'canceled', canceled.reload.status
        assert_equal 'expired',  expired.reload.status
      end

      test 'expire_overdue! defaults to provider:manual; does NOT touch non-manual providers' do
        stripe_sub = call(plan_key: 'pro', psid: 'sub_stripe', status: 'active',
                          current_period_end: 1.day.ago)
        # Force-set provider after creation (test setup uses provider: 'manual' by default)
        stripe_sub.update_column(:provider, 'stripe')

        rows = Subscriptions.expire_overdue!

        assert_empty rows
        assert_equal 'active', stripe_sub.reload.status
      end

      test 'expire_overdue! with explicit providers: includes those providers' do
        stripe_sub = call(plan_key: 'pro', psid: 'sub_stripe', status: 'active',
                          current_period_end: 1.day.ago)
        stripe_sub.update_column(:provider, 'stripe')

        rows = Subscriptions.expire_overdue!(providers: %w[stripe])

        assert_equal [stripe_sub.id], rows.map(&:id)
        assert_equal 'expired', stripe_sub.reload.status
      end

      test 'expire_overdue! is idempotent — calling twice expires nothing the second time' do
        call(plan_key: 'pro', psid: 'sub_manual', status: 'active',
             current_period_end: 1.day.ago)

        first  = Subscriptions.expire_overdue!
        second = Subscriptions.expire_overdue!

        assert_equal 1, first.size
        assert_empty second
      end

      test 'expire_overdue! fires :subscription_expired once per row' do
        sub_a = call(plan_key: 'pro', psid: 'sub_a', status: 'active',
                     current_period_end: 1.day.ago)
        sub_b = call(plan_key: 'pro', psid: 'sub_b', status: 'active', subject: @other,
                     current_period_end: 1.day.ago)
        captured = []
        RSB::Entitlements.on(:subscription_expired) { |row, from| captured << [row.id, from] }

        Subscriptions.expire_overdue!

        captured_ids = captured.map(&:first).sort
        assert_equal [sub_a.id, sub_b.id].sort, captured_ids
        assert(captured.all? { |_, from| from == 'active' })
      end

      test 'expire_overdue! honors injected clock for testability' do
        sub = call(plan_key: 'pro', psid: 'sub_future', status: 'active',
                   current_period_end: 2.days.from_now)

        # With a future clock, the row is "overdue" relative to that clock.
        rows = Subscriptions.expire_overdue!(clock: 3.days.from_now)

        assert_equal [sub.id], rows.map(&:id)
        assert_equal 'expired', sub.reload.status
      end

      # Reconciliation pattern documented in TDD §5.6: even with the new
      # default, the manual cancel-then-create flow still works.
      test 'reconciliation: cancel-then-create-new in one wrapping transaction succeeds' do
        first = call(plan_key: 'pro', psid: 'sub_1', status: 'active')

        ActiveRecord::Base.transaction do
          first.update!(status: 'canceled')
          call(plan_key: 'pro', psid: 'sub_2', status: 'active')
        end

        assert_equal 'canceled', first.reload.status
        assert_equal 1,
                     Subscription.where(
                       subject_type: @workspace.class.name,
                       subject_id: @workspace.id,
                       status: 'active'
                     ).count
      end

      # =====================================================================
      # Adapter-supplied created_at — backfill anchor (TDD §3, §5.1)
      # =====================================================================

      test 'sync! honors adapter-supplied created_at on insert' do
        anchor = 6.months.ago
        sub = call(plan_key: 'pro', psid: 'sub_backfill', created_at: anchor)

        assert_in_delta anchor.to_i, sub.created_at.to_i, 5
      end

      test 'sync! defaults created_at to Time.current on insert when omitted' do
        before = Time.current
        sub = call(plan_key: 'pro', psid: 'sub_default_anchor')
        after = Time.current

        assert_operator sub.created_at.to_f, :>=, before.to_f - 1
        assert_operator sub.created_at.to_f, :<=, after.to_f + 1
      end

      test 'sync! ignores adapter-supplied created_at on update (existing row)' do
        first = call(plan_key: 'pro', psid: 'sub_1')
        original_created_at = first.created_at

        # Try to "rewrite history" via a second sync! — this MUST be ignored.
        call(
          plan_key: 'pro',
          psid: 'sub_1',
          status: 'past_due',
          created_at: 10.years.ago
        )

        assert_in_delta original_created_at.to_i, first.reload.created_at.to_i, 1
      end
    end
  end
end
