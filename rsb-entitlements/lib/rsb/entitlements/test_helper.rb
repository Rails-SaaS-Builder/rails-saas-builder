# frozen_string_literal: true

module RSB
  module Entitlements
    # Test factories and +simulate_*+ helpers for rsb-entitlements v1.
    #
    # Usage:
    #
    #     class MyFeatureTest < ActiveSupport::TestCase
    #       include RSB::Entitlements::TestHelper
    #
    #       test 'my flow' do
    #         feature = create_test_feature(key: 'api_calls', kind: 'metered')
    #         plan    = create_test_plan(key: 'pro')
    #         attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')
    #         create_test_subscription(subject: @org, plan: plan)
    #         simulate_consume(@org, :api_calls, amount: 5)
    #         simulate_overage(@org, :api_calls, amount: 9999)
    #       end
    #     end
    #
    # The helper is plain Ruby (not +ActiveSupport::Concern+); host test
    # classes +include+ it directly. Including the module registers
    # +before_setup+ and +after_teardown+ callbacks via
    # +ActiveSupport::TestCase+'s DSL so that +RSB::Entitlements.reset!+
    # is called once at the start of every test (before any test-class
    # +setup do...end+ blocks) and once at the end (after test-class
    # +teardown do...end+ blocks). Hook subscribers registered in one test
    # therefore never leak into the next.
    module TestHelper
      # @api private
      # Registers before_setup / after_teardown callbacks when this module
      # is mixed into an ActiveSupport::TestCase host class.
      def self.included(base)
        base.setup    { RSB::Entitlements.reset! }
        base.teardown { RSB::Entitlements.reset! }
      end

      # Convenience wrapper around {RSB::Entitlements.reset!}.
      # Exposed as an instance method so +setup do...end+ blocks can call
      # +reset!+ directly without the full module prefix.
      #
      # @return [void]
      def reset!
        RSB::Entitlements.reset!
      end

      # Persist a {RSB::Entitlements::Feature} with sensible defaults.
      #
      # @param key [String, Symbol] feature key (required)
      # @param kind [String] one of +flag+/+metered+/+gauge+ (default +metered+)
      # @param unit [String, nil] free-form display unit (default +count+; pass +nil+ for flag)
      # @return [RSB::Entitlements::Feature] persisted record
      def create_test_feature(key:, kind: 'metered', unit: 'count')
        RSB::Entitlements::Feature.create!(
          key: key.to_s,
          name: key.to_s,
          kind: kind.to_s,
          unit: unit
        )
      end

      # Persist a {RSB::Entitlements::Plan}.
      #
      # @param key [String, Symbol] plan key (required)
      # @param name [String, nil] human-readable label; defaults to titleized key
      # @return [RSB::Entitlements::Plan] persisted record
      def create_test_plan(key:, name: nil)
        RSB::Entitlements::Plan.create!(key: key.to_s, name: name || key.to_s.titleize)
      end

      # Attach a feature to a plan as a {RSB::Entitlements::PlanFeature}.
      #
      # @param plan [RSB::Entitlements::Plan]
      # @param feature [RSB::Entitlements::Feature]
      # @param limit_value [Integer, nil] per-period cap (+metered+) or max (+gauge+); +nil+ = unlimited
      # @param period [String, nil] one of +day+/+week+/+month+/+year+ for metered; +nil+ for gauge/flag
      # @param enabled [Boolean, nil] meaningful for flag features only
      # @return [RSB::Entitlements::PlanFeature] persisted record
      def attach_test_feature(plan:, feature:, limit_value: nil, period: nil, enabled: nil)
        RSB::Entitlements::PlanFeature.create!(
          plan_key: plan.key,
          feature_key: feature.key,
          limit_value: limit_value,
          period: period,
          enabled: enabled
        )
      end

      # Persist a {RSB::Entitlements::Subscription} via {RSB::Entitlements::Subscriptions.sync!}.
      #
      # Routes through +sync!+ so production codepaths (partial-unique
      # enforcement, +:plan_changed+ hook, etc.) are exercised identically.
      #
      # @param subject [ActiveRecord::Base] polymorphic owner including +RSB::Entitlements::Subject+
      # @param plan [RSB::Entitlements::Plan]
      # @param status [String] one of the Subscription statuses (default +active+)
      # @param provider [String] payment provider key (default +manual+)
      # @param provider_subscription_id [String, nil] cross-system identity;
      #   defaults to +"manual_#{SecureRandom.hex(8)}"+
      # @param created_at [Time, nil] adapter-supplied anchor for backfill (insert only)
      # @return [RSB::Entitlements::Subscription] persisted record
      def create_test_subscription(subject:, plan:, status: 'active', provider: 'manual',
                                   provider_subscription_id: nil, created_at: nil)
        psid = provider_subscription_id || "manual_#{SecureRandom.hex(8)}"
        now  = Time.current
        RSB::Entitlements::Subscriptions.sync!(
          provider: provider,
          provider_subscription_id: psid,
          subject: subject,
          plan_key: plan.key,
          status: status,
          current_period_start: now,
          current_period_end: now + (100 * 365).days,
          created_at: created_at
        )
      end

      # Wrapper around +subject.consume!+. Returns the updated counter row.
      #
      # @param subject [ActiveRecord::Base]
      # @param feature_key [String, Symbol]
      # @param amount [Integer] default 1
      # @return [RSB::Entitlements::UsageCounter]
      def simulate_consume(subject, feature_key, amount: 1)
        subject.consume!(feature_key, amount: amount)
      end

      # Wrapper around +subject.release!+ (gauge-only). Returns the updated counter row.
      #
      # @param subject [ActiveRecord::Base]
      # @param feature_key [String, Symbol]
      # @param amount [Integer] default 1
      # @return [RSB::Entitlements::UsageCounter]
      def simulate_release(subject, feature_key, amount: 1)
        subject.release!(feature_key, amount: amount)
      end

      # Asserts that consuming +amount+ raises {RSB::Entitlements::OverLimit}.
      #
      # @param subject [ActiveRecord::Base]
      # @param feature_key [String, Symbol]
      # @param amount [Integer] default 1
      # @return [RSB::Entitlements::OverLimit] the assertion's captured exception
      def simulate_overage(subject, feature_key, amount: 1)
        assert_raises(RSB::Entitlements::OverLimit) do
          subject.consume!(feature_key, amount: amount)
        end
      end

      # Asserts that releasing +amount+ raises {RSB::Entitlements::CannotRelease}.
      #
      # @param subject [ActiveRecord::Base]
      # @param feature_key [String, Symbol]
      # @param amount [Integer] default 1
      # @return [RSB::Entitlements::CannotRelease] the assertion's captured exception
      def simulate_release_blocked(subject, feature_key, amount: 1)
        assert_raises(RSB::Entitlements::CannotRelease) do
          subject.release!(feature_key, amount: amount)
        end
      end
    end
  end
end
