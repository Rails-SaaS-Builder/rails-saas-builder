# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class ResolverTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        # TestHelper#setup already calls RSB::Entitlements.reset!
        # The gem's dummy app exposes an Organization AR model; the resolver only
        # needs subject.class.name and subject.id.
        @subject = Organization.create!(name: 'Acme')
      end

      teardown do
        # TestHelper#teardown calls RSB::Entitlements.reset!
      end

      # --- nil cases ---

      test 'returns nil when subject has no subscription at all' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        assert_nil Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
      end

      test 'returns nil when subject has only canceled subscriptions' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'canceled')

        assert_nil Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
      end

      test 'returns nil for incomplete / past_due / expired statuses' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')

        %w[incomplete past_due expired canceled].each do |status|
          # Need a unique provider_subscription_id per row to satisfy the cross-system
          # uniqueness index; partial-unique-index allows multiple non-active rows.
          create_test_subscription(
            subject: @subject, plan: plan, status: status,
            provider_subscription_id: "manual_#{status}_#{SecureRandom.hex(4)}"
          )
          assert_nil Resolver.grant_for(subject: @subject, feature_key: 'api_calls'),
                     "expected nil for status=#{status}"
        end
      end

      test 'returns nil when active subscription plan has no plan_features row' do
        create_test_feature(key: 'api_calls', kind: 'metered')
        plan = create_test_plan(key: 'pro')
        # No attach_test_feature — plan grants nothing.
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        assert_nil Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
      end

      # --- happy paths per kind ---

      test 'returns Grant for metered feature with active subscription' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        sub = create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'api_calls')

        refute_nil grant
        assert_equal sub.id, grant.subscription.id
        assert_equal 'pro', grant.plan_key
        assert_equal 'metered', grant.feature_kind
        assert_nil grant.enabled
        assert_equal 1_000, grant.limit
        assert_equal 'month', grant.period
        assert_nil grant.counter # no usage row yet
      end

      test 'returns Grant for trialing subscription (status: trialing counts as active)' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'trialing')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
        refute_nil grant
        assert_equal 'pro', grant.plan_key
      end

      test 'returns Grant for flag feature with enabled=true' do
        feature = create_test_feature(key: 'sso', kind: 'flag')
        plan    = create_test_plan(key: 'enterprise')
        attach_test_feature(plan: plan, feature: feature, enabled: true)
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'sso')
        refute_nil grant
        assert_equal 'flag', grant.feature_kind
        assert_equal true, grant.enabled
        assert_nil grant.limit
        assert_nil grant.period
      end

      test 'returns Grant for flag feature with enabled=false (still returns the grant)' do
        feature = create_test_feature(key: 'sso', kind: 'flag')
        plan    = create_test_plan(key: 'free')
        attach_test_feature(plan: plan, feature: feature, enabled: false)
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'sso')
        refute_nil grant
        assert_equal false, grant.enabled
      end

      test 'returns Grant for gauge feature with limit and nil period' do
        feature = create_test_feature(key: 'projects', kind: 'gauge', unit: 'count')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 25, period: nil)
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'projects')
        refute_nil grant
        assert_equal 'gauge', grant.feature_kind
        assert_equal 25, grant.limit
        assert_nil grant.period
      end

      # --- counter wiring ---

      test 'counter is nil when no usage_counters row exists' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
        assert_nil grant.counter
      end

      test 'counter is populated when a usage_counters row exists for the (subject, feature)' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        counter = UsageCounter.create!(
          subject_type: @subject.class.name,
          subject_id: @subject.id,
          feature_key: 'api_calls',
          period_start: 1.day.ago,
          consumed: 42
        )

        grant = Resolver.grant_for(subject: @subject, feature_key: 'api_calls')
        refute_nil grant.counter
        assert_equal counter.id, grant.counter.id
        assert_equal 42, grant.counter.consumed
      end

      # --- coercion ---

      test 'accepts symbol feature_key' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        grant = Resolver.grant_for(subject: @subject, feature_key: :api_calls)
        refute_nil grant
        assert_equal 'metered', grant.feature_kind
      end

      # --- subject scoping ---

      test 'does not leak grants across subjects with same id but different type' do
        feature = create_test_feature(key: 'api_calls', kind: 'metered')
        plan    = create_test_plan(key: 'pro')
        attach_test_feature(plan: plan, feature: feature, limit_value: 1_000, period: 'month')
        create_test_subscription(subject: @subject, plan: plan, status: 'active')

        # A fake other-typed subject with the same id should not pick up the grant.
        other = Struct.new(:id, :class_name) do
          def class
            # Return a class-like object whose .name differs from Organization
            Struct.new(:name).new('OtherType')
          end
        end.new(@subject.id, 'OtherType')

        assert_nil Resolver.grant_for(subject: other, feature_key: 'api_calls')
      end

      private

      # Create a Feature record for resolver tests.
      #
      # @param key [String] feature key
      # @param kind [String] "flag", "metered", or "gauge"
      # @param unit [String, nil] optional unit label
      # @return [RSB::Entitlements::Feature]
      def create_test_feature(key:, kind:, unit: nil)
        Feature.create!(key: key, name: key, kind: kind, unit: unit)
      end

      # Create a Plan record for resolver tests.
      #
      # @param key [String] plan key
      # @return [RSB::Entitlements::Plan]
      def create_test_plan(key:)
        Plan.create!(key: key, name: key)
      end

      # Attach a feature to a plan (creates a PlanFeature row).
      #
      # @param plan [RSB::Entitlements::Plan]
      # @param feature [RSB::Entitlements::Feature]
      # @param attrs [Hash] extra PlanFeature attributes (enabled, limit_value, period)
      # @return [RSB::Entitlements::PlanFeature]
      def attach_test_feature(plan:, feature:, **attrs)
        PlanFeature.create!(plan_key: plan.key, feature_key: feature.key, **attrs)
      end

      # Create a Subscription record for resolver tests.
      #
      # @param subject [ActiveRecord::Base] the polymorphic owner
      # @param plan [RSB::Entitlements::Plan]
      # @param status [String] subscription status
      # @param provider_subscription_id [String] unique provider id
      # @return [RSB::Entitlements::Subscription]
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
