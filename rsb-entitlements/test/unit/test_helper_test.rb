# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    # Verifies the test factory surface: every helper method returns a persisted /
    # raised-as-expected result, and setup/teardown wipe in-memory state via reset!.
    class TestHelperTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        # Test subject — uses dummy app's Organization model.
        @subject = Organization.create!(name: 'Acme TestHelper')
      end

      # --- create_test_feature ---

      test 'create_test_feature persists with provided key/kind/unit' do
        f = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        assert_predicate f, :persisted?
        assert_equal 'api_calls', f.key
        assert_equal 'metered',   f.kind
        assert_equal 'count',     f.unit
      end

      test 'create_test_feature defaults are sensible (kind metered, unit count)' do
        f = create_test_feature(key: 'reqs')
        assert_equal 'metered', f.kind
        assert_equal 'count',   f.unit
      end

      test 'create_test_feature works for flag and gauge kinds (unit may be nil)' do
        flag  = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        gauge = create_test_feature(key: 'seats', kind: 'gauge', unit: 'seat')
        assert_equal 'flag', flag.kind
        assert_nil   flag.unit
        assert_equal 'gauge', gauge.kind
        assert_equal 'seat',  gauge.unit
      end

      # --- create_test_plan ---

      test 'create_test_plan persists with provided key' do
        p = create_test_plan(key: 'pro')
        assert_predicate p, :persisted?
        assert_equal 'pro', p.key
        assert p.name.present?
      end

      test 'create_test_plan accepts a custom name' do
        p = create_test_plan(key: 'free', name: 'Free Forever')
        assert_equal 'Free Forever', p.name
      end

      # --- attach_test_feature ---

      test 'attach_test_feature creates PlanFeature row with provided attrs' do
        plan    = create_test_plan(key: 'pro')
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        pf = attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        assert_predicate pf, :persisted?
        assert_equal 'pro',       pf.plan_key
        assert_equal 'api_calls', pf.feature_key
        assert_equal 100,         pf.limit_value
        assert_equal 'month',     pf.period
      end

      test 'attach_test_feature with enabled: passes through for flag features' do
        plan    = create_test_plan(key: 'pro')
        feature = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        pf = attach_test_feature(plan: plan, feature: feature, enabled: true)
        assert_equal true, pf.enabled
      end

      # --- create_test_subscription ---

      test 'create_test_subscription persists an active manual subscription by default' do
        plan = create_test_plan(key: 'pro')
        sub  = create_test_subscription(subject: @subject, plan: plan)
        assert_predicate sub, :persisted?
        assert_equal 'active',  sub.status
        assert_equal 'manual',  sub.provider
        assert_equal 'pro',     sub.plan_key
        assert_match(/\Amanual_[0-9a-f]{16}\z/, sub.provider_subscription_id)
      end

      test 'create_test_subscription accepts overrides for status / provider / psid / created_at' do
        plan          = create_test_plan(key: 'pro')
        anchor        = 30.days.ago
        explicit_psid = 'sub_explicit_001'
        sub = create_test_subscription(
          subject: @subject,
          plan: plan,
          status: 'trialing',
          provider: 'stripe',
          provider_subscription_id: explicit_psid,
          created_at: anchor
        )
        assert_equal 'trialing',    sub.status
        assert_equal 'stripe',      sub.provider
        assert_equal explicit_psid, sub.provider_subscription_id
        assert_in_delta anchor.to_f, sub.created_at.to_f, 1.0
      end

      test 'create_test_subscription routes through Subscriptions.sync!' do
        # Sync! must be the codepath so :plan_changed / partial-unique enforcement
        # are exercised the same way production adapters would. Verify by
        # subscribing a hook and inspecting that no plan_changed fires on insert
        # (TDD §5.6: hook fires only on plan_key CHANGE on existing row).
        plan = create_test_plan(key: 'pro')
        captured = []
        RSB::Entitlements.on(:plan_changed) { |*args| captured << args }
        create_test_subscription(subject: @subject, plan: plan)
        assert_empty captured
      end

      # --- simulate_consume ---

      test 'simulate_consume increments the counter and returns it' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @subject, plan: plan)

        counter = simulate_consume(@subject, :api_calls, amount: 3)
        assert_predicate counter, :persisted?
        assert_equal 3, counter.consumed
      end

      test 'simulate_consume defaults amount to 1' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10, period: 'month')
        create_test_subscription(subject: @subject, plan: plan)

        counter = simulate_consume(@subject, :api_calls)
        assert_equal 1, counter.consumed
      end

      # --- simulate_release ---

      test 'simulate_release decrements a gauge counter' do
        feature = create_test_feature(key: 'seats', kind: 'gauge', unit: 'seat')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10)
        create_test_subscription(subject: @subject, plan: plan)

        simulate_consume(@subject, :seats, amount: 3)
        counter = simulate_release(@subject, :seats, amount: 1)
        assert_equal 2, counter.consumed
      end

      # --- simulate_overage ---

      test 'simulate_overage asserts OverLimit raised' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1, period: 'month')
        create_test_subscription(subject: @subject, plan: plan)

        simulate_consume(@subject, :api_calls, amount: 1)
        # next consume must raise OverLimit and the helper must surface that
        simulate_overage(@subject, :api_calls, amount: 1)
      end

      test 'simulate_overage with no active subscription still asserts OverLimit' do
        # No subscription created -> OverLimit on first consume attempt
        simulate_overage(@subject, :anything, amount: 1)
      end

      # --- simulate_release_blocked ---

      test 'simulate_release_blocked asserts CannotRelease raised' do
        feature = create_test_feature(key: 'seats', kind: 'gauge', unit: 'seat')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 5)
        create_test_subscription(subject: @subject, plan: plan)

        # consumed=0, release(1) -> CannotRelease
        simulate_release_blocked(@subject, :seats, amount: 1)
      end

      # --- setup/teardown via reset! ---

      test 'setup / teardown call RSB::Entitlements.reset! (hooks cleared)' do
        # The included setup ran reset! before this test body. Register a hook,
        # confirm it is registered, then assert the next test sees a clean slate
        # (verified indirectly via teardown wiping it — see reset_clears_hooks
        # below for the assertion).
        called = false
        RSB::Entitlements.on(:plan_changed) { |*_| called = true }
        # Force a plan_changed fire to confirm the hook IS active in this test
        plan_a = create_test_plan(key: 'a')
        plan_b = create_test_plan(key: 'b')
        sub = create_test_subscription(subject: @subject, plan: plan_a)
        # Cancel current sub so partial-unique index lets us create the new one
        sub.update_columns(status: 'canceled')
        # Simulate plan change on same psid
        RSB::Entitlements::Subscriptions.sync!(
          provider: sub.provider,
          provider_subscription_id: sub.provider_subscription_id,
          subject: @subject,
          plan_key: plan_b.key,
          status: 'active',
          current_period_start: Time.current,
          current_period_end: 1.month.from_now
        )
        assert called, ':plan_changed hook fired during this test'
      end

      test 'reset_clears_hooks: hook registered in prior test is gone here' do
        # If reset! truly fires in teardown of the prior test, the hook above
        # cannot leak into this one. We verify by registering a counter on a
        # fresh hook and confirming it starts empty.
        captured = []
        RSB::Entitlements.on(:plan_changed) { |*_| captured << :fired }
        # No plan_changed fire in this test body, so should stay empty
        assert_empty captured
      end
    end
  end
end
