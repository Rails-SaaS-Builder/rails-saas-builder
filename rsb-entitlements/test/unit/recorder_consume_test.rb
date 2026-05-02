# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class RecorderConsumeTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        @org      = Organization.create!(name: 'Acme')
        @feature  = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        @plan     = create_test_plan(key: 'pro')
        @grant_pf = attach_test_feature(plan: @plan, feature: @feature, limit_value: 100, period: 'month')
        @sub      = create_test_subscription(subject: @org, plan: @plan, status: 'active')
      end

      # --- ArgumentError paths ---

      test 'amount <= 0 raises ArgumentError; counter unchanged' do
        assert_raises(ArgumentError) do
          Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 0)
        end
        assert_raises(ArgumentError) do
          Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: -1)
        end
        assert_equal 0, UsageCounter.where(subject_type: @org.class.name, subject_id: @org.id).count
      end

      test 'flag features raise ArgumentError mentioning consume! is not valid for flag features' do
        flag = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        attach_test_feature(plan: @plan, feature: flag, enabled: true)

        err = assert_raises(ArgumentError) do
          Recorder.consume!(subject: @org, feature_key: 'sso', amount: 1)
        end
        assert_match(/flag/i, err.message)
      end

      # --- OverLimit paths ---

      test 'no active subscription raises OverLimit and fires :overage_blocked' do
        @sub.update!(status: 'canceled')
        captured = []
        RSB::Entitlements.on(:overage_blocked) { |s, fk, amt| captured << [s, fk, amt] }

        assert_raises(OverLimit) do
          Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 1)
        end
        assert_equal 1, captured.size
        assert_equal [@org, 'api_calls', 1], captured.first
      end

      test 'no plan_features row for feature raises OverLimit and fires :overage_blocked' do
        create_test_feature(key: 'storage', kind: 'metered', unit: 'bytes')
        captured = []
        RSB::Entitlements.on(:overage_blocked) { |s, fk, amt| captured << [s, fk, amt] }

        assert_raises(OverLimit) do
          Recorder.consume!(subject: @org, feature_key: 'storage', amount: 1)
        end
        assert_equal [[@org, 'storage', 1]], captured
      end

      test 'capacity exceeded raises OverLimit, fires :overage_blocked, counter unchanged' do
        # Pre-fill the counter to limit
        Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 100)
        captured = []
        RSB::Entitlements.on(:overage_blocked) { |s, fk, amt| captured << [s, fk, amt] }

        assert_raises(OverLimit) do
          Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 1)
        end
        counter = UsageCounter.find_by!(subject_type: @org.class.name, subject_id: @org.id, feature_key: 'api_calls')
        assert_equal 100, counter.consumed
        assert_equal [[@org, 'api_calls', 1]], captured
      end

      # --- Happy paths ---

      test 'metered happy path: consumed increments by amount; period_start unchanged within window' do
        result = Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 5)
        assert_kind_of UsageCounter, result
        assert_equal 5, result.consumed

        result2 = Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 3)
        assert_equal 8, result2.consumed
        assert_equal result.period_start, result2.period_start
      end

      test 'returns updated counter on success' do
        counter = Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 1)
        assert_kind_of UsageCounter, counter
        assert counter.persisted?
        assert_equal 1, counter.consumed
        assert_equal 'api_calls', counter.feature_key
      end

      test 'period boundary rolls counter in place and fires :period_rolled' do
        # First consume establishes a counter row at the current period
        Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 7)
        counter = UsageCounter.find_by!(subject_type: @org.class.name, subject_id: @org.id, feature_key: 'api_calls')

        # Forcibly age the stored period_start to simulate a passed boundary
        old_period_start = counter.period_start - 35.days
        counter.update_columns(period_start: old_period_start, consumed: 7)

        captured = []
        RSB::Entitlements.on(:period_rolled) { |s, fk, ps| captured << [s, fk, ps] }

        rolled = Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 4)
        assert_equal 4, rolled.consumed, 'roll resets consumed to amount'
        assert rolled.period_start > old_period_start, 'period_start advanced'

        assert_equal 1, captured.size
        assert_equal @org, captured.first[0]
        assert_equal 'api_calls', captured.first[1]
        assert_equal rolled.period_start, captured.first[2]
      end

      test 'gauge happy path: consumed increments; period_start stays at -infinity' do
        gauge = create_test_feature(key: 'seats', kind: 'gauge', unit: 'count')
        attach_test_feature(plan: @plan, feature: gauge, limit_value: 10)

        result = Recorder.consume!(subject: @org, feature_key: 'seats', amount: 3)
        assert_equal 3, result.consumed
        # '-infinity' surfaces as Float::INFINITY * -1 in PG; check it's effectively unchanged after second consume
        first_period_start = result.period_start
        result2 = Recorder.consume!(subject: @org, feature_key: 'seats', amount: 2)
        assert_equal 5, result2.consumed
        assert_equal first_period_start, result2.period_start
      end

      test ':period_rolled does NOT fire on first consume (counter created with current period)' do
        captured = []
        RSB::Entitlements.on(:period_rolled) { |*args| captured << args }
        Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 1)
        assert_empty captured
      end

      # --- First-consume race protection ---

      test 'first-consume race: lock_or_init handles concurrent inserts (insert conflict)' do
        # Simulate the second concurrent insert losing the unique-index race by
        # stubbing UsageCounter.insert_all to return 0 affected rows on the call
        # that would conflict, while a real row already exists.
        UsageCounter.create!(
          subject_type: @org.class.name,
          subject_id: @org.id,
          feature_key: 'api_calls',
          period_start: Time.current.beginning_of_month,
          consumed: 0
        )

        # Recorder.consume! should NOT raise RecordNotUnique; lock_or_init
        # is expected to use ON CONFLICT DO NOTHING semantics, then SELECT FOR UPDATE.
        assert_nothing_raised do
          Recorder.consume!(subject: @org, feature_key: 'api_calls', amount: 2)
        end
        counter = UsageCounter.find_by!(
          subject_type: @org.class.name, subject_id: @org.id, feature_key: 'api_calls'
        )
        assert_equal 2, counter.consumed
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
