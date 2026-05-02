# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class RecorderReleaseTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        @org      = Organization.create!(name: 'Acme')
        @gauge    = create_test_feature(key: 'seats', kind: 'gauge', unit: 'count')
        @plan     = create_test_plan(key: 'pro')
        attach_test_feature(plan: @plan, feature: @gauge, limit_value: 10)
        @sub = create_test_subscription(subject: @org, plan: @plan, status: 'active')
      end

      test 'amount <= 0 raises ArgumentError' do
        assert_raises(ArgumentError) do
          Recorder.release!(subject: @org, feature_key: 'seats', amount: 0)
        end
        assert_raises(ArgumentError) do
          Recorder.release!(subject: @org, feature_key: 'seats', amount: -1)
        end
      end

      test 'feature kind != gauge raises ArgumentError' do
        metered = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
        attach_test_feature(plan: @plan, feature: metered, limit_value: 100, period: 'month')

        err = assert_raises(ArgumentError) do
          Recorder.release!(subject: @org, feature_key: 'api_calls', amount: 1)
        end
        assert_match(/gauge/i, err.message)

        flag = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
        attach_test_feature(plan: @plan, feature: flag, enabled: true)
        assert_raises(ArgumentError) do
          Recorder.release!(subject: @org, feature_key: 'sso', amount: 1)
        end
      end

      test 'no active grant raises CannotRelease and fires :release_blocked' do
        @sub.update!(status: 'canceled')
        captured = []
        RSB::Entitlements.on(:release_blocked) { |s, fk, amt| captured << [s, fk, amt] }

        assert_raises(CannotRelease) do
          Recorder.release!(subject: @org, feature_key: 'seats', amount: 1)
        end
        assert_equal [[@org, 'seats', 1]], captured
      end

      test 'consumed < amount raises CannotRelease, fires :release_blocked, counter unchanged' do
        Recorder.consume!(subject: @org, feature_key: 'seats', amount: 2)
        captured = []
        RSB::Entitlements.on(:release_blocked) { |s, fk, amt| captured << [s, fk, amt] }

        assert_raises(CannotRelease) do
          Recorder.release!(subject: @org, feature_key: 'seats', amount: 5)
        end
        counter = UsageCounter.find_by!(subject_type: @org.class.name, subject_id: @org.id, feature_key: 'seats')
        assert_equal 2, counter.consumed
        assert_equal [[@org, 'seats', 5]], captured
      end

      test 'happy path: counter.consumed decrements by amount' do
        Recorder.consume!(subject: @org, feature_key: 'seats', amount: 7)
        result = Recorder.release!(subject: @org, feature_key: 'seats', amount: 3)
        assert_kind_of UsageCounter, result
        assert_equal 4, result.consumed

        # Release down to zero is allowed
        result2 = Recorder.release!(subject: @org, feature_key: 'seats', amount: 4)
        assert_equal 0, result2.consumed
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
