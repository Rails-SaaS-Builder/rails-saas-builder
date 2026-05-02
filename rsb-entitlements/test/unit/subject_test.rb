# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class SubjectTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        # TestHelper#setup calls RSB::Entitlements.reset!.
        # `Organization` is the gem's dummy-app subject (declared in test/dummy)
        # and includes `RSB::Entitlements::Subject` per Task 15's dummy wiring.
        @org = Organization.create!(name: 'Acme')
      end

      # --- entitled_to? : flag ---

      test 'entitled_to? returns true for flag granted with enabled=true' do
        feature = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        plan    = create_test_plan(key: 'enterprise')
        attach_test_feature(plan: plan, feature: feature, enabled: true)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal true, @org.entitled_to?(:sso)
      end

      test 'entitled_to? returns false for flag granted with enabled=false' do
        feature = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        plan    = create_test_plan(key: 'free')
        attach_test_feature(plan: plan, feature: feature, enabled: false)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal false, @org.entitled_to?(:sso)
      end

      # --- entitled_to? : metered ---

      test 'entitled_to? returns true for metered with consumed < limit' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        # No counter row -> consumed treated as 0 -> 0 < 100 -> true
        assert_equal true, @org.entitled_to?(:api_calls)
      end

      test 'entitled_to? returns false for metered when consumed equals limit' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10, period: 'month')
        sub = create_test_subscription(subject: @org, plan: plan, status: 'active')

        # Anchor the stored period_start to the period the resolver will compute now,
        # so `effective_consumed` reads the stored value (not zero).
        period_start_now = PeriodCalculator.period_start_for(
          period: 'month', anchor: sub.created_at, clock: Time.current
        )
        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: period_start_now, consumed: 10
        )

        assert_equal false, @org.entitled_to?(:api_calls)
      end

      test 'entitled_to? returns true for metered when limit is nil (unlimited)' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'enterprise')
        attach_test_feature(plan: plan, feature: feature, limit_value: nil, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: 1.day.ago, consumed: 99_999
        )
        assert_equal true, @org.entitled_to?(:api_calls)
      end

      # --- entitled_to? : gauge ---

      test 'entitled_to? returns true for gauge when consumed < limit' do
        feature = create_test_feature(key: 'projects', kind: 'gauge', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 5, period: nil)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'projects', period_start: Time.zone.at(0), consumed: 3
        )
        assert_equal true, @org.entitled_to?(:projects)
      end

      test 'entitled_to? returns false for gauge when consumed equals limit' do
        feature = create_test_feature(key: 'projects', kind: 'gauge', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 5, period: nil)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'projects', period_start: Time.zone.at(0), consumed: 5
        )
        assert_equal false, @org.entitled_to?(:projects)
      end

      # --- entitled_to? : no grant ---

      test 'entitled_to? returns false when subject has no active subscription' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        assert_equal false, @org.entitled_to?(:api_calls)
      end

      test 'entitled_to? returns false when active plan has no plan_features row' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        plan = create_test_plan(key: 'pro')
        # No attach_test_feature -- plan grants nothing.
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal false, @org.entitled_to?(:api_calls)
      end

      # --- LAZY ROLL : read-only methods do not mutate the counter row ---

      test 'entitled_to? on metered with stale period_start treats consumed as 0 without mutating row' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        stale_period_start = 2.months.ago
        counter = UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: stale_period_start, consumed: 100
        )

        # Lazy roll: stored consumed is 100/100 but the period rolled -> should report true.
        assert_equal true, @org.entitled_to?(:api_calls)

        # Row is NOT mutated by the read.
        counter.reload
        assert_equal 100, counter.consumed
        assert_in_delta stale_period_start.to_f, counter.period_start.to_f, 1.0
      end

      test 'remaining_for on metered with stale period_start returns full limit without mutating row' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        stale_period_start = 2.months.ago
        counter = UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: stale_period_start, consumed: 100
        )

        assert_equal 100, @org.remaining_for(:api_calls)

        counter.reload
        assert_equal 100, counter.consumed
        assert_in_delta stale_period_start.to_f, counter.period_start.to_f, 1.0
      end

      # --- limit_for ---

      test 'limit_for returns Integer when limited' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal 1_000, @org.limit_for(:api_calls)
      end

      test 'limit_for returns nil when unlimited' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'enterprise')
        attach_test_feature(plan: plan, feature: feature, limit_value: nil, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_nil @org.limit_for(:api_calls)
      end

      test 'limit_for returns false when no grant exists' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        assert_equal false, @org.limit_for(:api_calls)
      end

      # --- remaining_for ---

      test 'remaining_for returns Integer clamped at 0' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10, period: 'month')
        sub = create_test_subscription(subject: @org, plan: plan, status: 'active')

        period_start_now = PeriodCalculator.period_start_for(
          period: 'month', anchor: sub.created_at, clock: Time.current
        )
        # Over-consumption (e.g., post-downgrade): consumed > limit
        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: period_start_now, consumed: 25
        )
        assert_equal 0, @org.remaining_for(:api_calls)
      end

      test 'remaining_for returns nil when unlimited' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'enterprise')
        attach_test_feature(plan: plan, feature: feature, limit_value: nil, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_nil @org.remaining_for(:api_calls)
      end

      test 'remaining_for returns 0 when no grant exists' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        assert_equal 0, @org.remaining_for(:api_calls)
      end

      # --- grant_for ---

      test 'grant_for returns hash with effective consumed and effective period_start (metered)' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        sub = create_test_subscription(subject: @org, plan: plan, status: 'active')

        period_start_now = PeriodCalculator.period_start_for(
          period: 'month', anchor: sub.created_at, clock: Time.current
        )
        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: period_start_now, consumed: 7
        )

        grant = @org.grant_for(:api_calls)
        assert_equal 'pro', grant[:plan_key]
        assert_equal 100, grant[:limit]
        assert_equal 7, grant[:consumed]
        assert_in_delta period_start_now.to_f, grant[:period_start].to_f, 1.0
        assert_equal 'month', grant[:period]
      end

      test 'grant_for returns hash with effective consumed = 0 when stored period_start is stale (metered)' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        UsageCounter.create!(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls', period_start: 2.months.ago, consumed: 100
        )

        grant = @org.grant_for(:api_calls)
        assert_equal 0, grant[:consumed]
      end

      test 'grant_for returns nil when no active grant exists' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        assert_nil @org.grant_for(:api_calls)
      end

      test 'grant_for works for flag features (no period — must not call PeriodCalculator)' do
        feature = create_test_feature(key: 'sso', kind: 'flag')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, enabled: true)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        # Must not raise — flag has period=nil, so PeriodCalculator must not
        # be invoked. Counter row may not exist for a flag (it's read-only).
        grant = nil
        assert_nothing_raised { grant = @org.grant_for(:sso) }
        refute_nil grant
        assert_equal 'pro', grant[:plan_key]
        assert_nil grant[:period]
      end

      test 'grant_for works for gauge features when no counter row exists yet' do
        feature = create_test_feature(key: 'storage', kind: 'gauge')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        grant = nil
        assert_nothing_raised { grant = @org.grant_for(:storage) }
        refute_nil grant
        assert_equal 0, grant[:consumed]
      end

      # --- consume! / release! delegate to Recorder ---

      test 'consume! delegates to Recorder and returns the counter' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        result = @org.consume!(:api_calls, amount: 3)
        assert_kind_of UsageCounter, result
        assert_equal 3, result.consumed
      end

      test 'consume! amount defaults to 1' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        result = @org.consume!(:api_calls)
        assert_equal 1, result.consumed
      end

      test 'release! delegates to Recorder for gauge feature' do
        feature = create_test_feature(key: 'projects', kind: 'gauge', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10, period: nil)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        @org.consume!(:projects, amount: 4)
        result = @org.release!(:projects, amount: 1)
        assert_kind_of UsageCounter, result
        assert_equal 3, result.consumed
      end

      test 'release! amount defaults to 1' do
        feature = create_test_feature(key: 'projects', kind: 'gauge', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 10, period: nil)
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        @org.consume!(:projects, amount: 2)
        result = @org.release!(:projects)
        assert_equal 1, result.consumed
      end

      # --- active_subscription ---

      test 'active_subscription returns the active sub when one exists' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        sub = create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal sub.id, @org.active_subscription.id
      end

      test 'active_subscription returns the trialing sub when one exists' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        sub = create_test_subscription(subject: @org, plan: plan, status: 'trialing')

        assert_equal sub.id, @org.active_subscription.id
      end

      test 'active_subscription returns nil when only canceled / past_due rows exist' do
        plan = create_test_plan(key: 'pro')
        create_test_subscription(subject: @org, plan: plan, status: 'canceled')
        assert_nil @org.active_subscription
      end

      # --- key coercion ---

      test 'all read methods accept symbol or string feature keys' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @org, plan: plan, status: 'active')

        assert_equal true,  @org.entitled_to?('api_calls')
        assert_equal 100,   @org.limit_for('api_calls')
        assert_equal 100,   @org.remaining_for('api_calls')
        refute_nil          @org.grant_for('api_calls')
      end

      private

      def create_test_feature(key:, kind:, unit: nil)
        Feature.create!(key: key, name: key, kind: kind, unit: unit)
      end

      def create_test_plan(key:)
        Plan.create!(key: key, name: key)
      end

      def attach_test_feature(plan:, feature:, **attrs)
        PlanFeature.create!(plan_key: plan.key, feature_key: feature.key, **attrs)
      end

      def create_test_subscription(subject:, plan:, status:, provider_subscription_id: nil)
        Subscription.create!(
          subject_type: subject.class.name,
          subject_id: subject.id,
          plan_key: plan.key,
          status: status,
          current_period_start: Time.current,
          current_period_end: 1.month.from_now,
          provider: 'manual',
          provider_subscription_id: provider_subscription_id || SecureRandom.hex(8)
        )
      end
    end
  end
end
