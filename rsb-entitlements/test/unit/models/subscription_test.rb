# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class SubscriptionTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      STATUSES = %w[incomplete trialing active past_due canceled expired].freeze

      setup do
        @plan = Plan.create!(key: 'pro', name: 'Pro')
        Plan.create!(key: 'free', name: 'Free')
        @workspace_one = Organization.create!(name: 'Acme')   # dummy app subject
        @workspace_two = Organization.create!(name: 'Globex') # different subject for partial-unique tests
      end

      def base_attrs
        {
          subject_type: @workspace_one.class.name, subject_id: @workspace_one.id,
          plan_key: 'pro', status: 'active',
          current_period_start: Time.current, current_period_end: 1.month.from_now,
          provider: 'manual', provider_subscription_id: SecureRandom.hex(8),
          raw_state: {}
        }
      end

      # --- Associations ---

      test 'belongs_to plan via plan_key → plans.key' do
        sub = Subscription.create!(base_attrs)
        assert_equal @plan, sub.plan
      end

      # --- Status enum ---

      test 'accepts each valid status' do
        STATUSES.each do |status|
          attrs = base_attrs.merge(
            status: status,
            provider_subscription_id: SecureRandom.hex(8),
            # only one active/trialing allowed per subject — vary subject to avoid
            # tripping the partial unique index
            subject_id: @workspace_two.id
          )
          sub = Subscription.create!(attrs)
          assert sub.persisted?, "expected #{status} valid"
          assert_equal status, sub.status
          # bust subject_two for next iteration to avoid double-active conflict
          sub.update!(status: 'canceled') if %w[active trialing].include?(status)
        end
      end

      test 'rejects invalid status (Rails enum validate: true)' do
        assert_raises(ArgumentError) do
          Subscription.new(base_attrs.merge(status: 'unknown'))
        end
      end

      test 'enum predicates exist for each status' do
        sub = Subscription.new(base_attrs.merge(status: 'trialing'))
        assert sub.trialing?
        refute sub.active?
        refute sub.canceled?
      end

      # --- Presence validations ---

      test 'requires subject_type, subject_id, plan_key, status, periods, provider, provider_subscription_id' do
        sub = Subscription.new
        refute sub.valid?
        %i[subject_type subject_id plan_key status
           current_period_start current_period_end provider provider_subscription_id].each do |attr|
          assert sub.errors[attr].any?, "expected presence error on #{attr}"
        end
      end

      # --- Uniqueness on (provider, provider_subscription_id) ---

      test 'rejects duplicate (provider, provider_subscription_id) at model level' do
        Subscription.create!(base_attrs.merge(provider_subscription_id: 'dup1'))
        dup = Subscription.new(base_attrs.merge(
                                 provider_subscription_id: 'dup1',
                                 subject_id: @workspace_two.id,
                                 status: 'canceled'
                               ))
        refute dup.valid?
        assert dup.errors[:provider_subscription_id].any?
      end

      test 'permits same provider_subscription_id under a different provider' do
        Subscription.create!(base_attrs.merge(provider: 'stripe', provider_subscription_id: 'sub_X'))
        ok = Subscription.create!(base_attrs.merge(
                                    provider: 'manual',
                                    provider_subscription_id: 'sub_X',
                                    subject_id: @workspace_two.id
                                  ))
        assert ok.persisted?
      end

      # --- Scopes ---

      test 'scope :active_or_trialing includes active and trialing only' do
        Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'a'))
        Subscription.create!(base_attrs.merge(status: 'trialing',
                                              subject_id: @workspace_two.id,
                                              provider_subscription_id: 'b'))
        # noise rows in non-resolving statuses
        Subscription.create!(base_attrs.merge(status: 'canceled',
                                              subject_id: @workspace_two.id,
                                              provider_subscription_id: 'c'))
        Subscription.create!(base_attrs.merge(status: 'expired',
                                              subject_id: @workspace_two.id,
                                              provider_subscription_id: 'd'))
        Subscription.create!(base_attrs.merge(status: 'past_due',
                                              subject_id: @workspace_two.id,
                                              provider_subscription_id: 'e'))
        Subscription.create!(base_attrs.merge(status: 'incomplete',
                                              subject_id: @workspace_two.id,
                                              provider_subscription_id: 'f'))
        assert_equal 2, Subscription.active_or_trialing.count
      end

      test 'scope :for_subject narrows by polymorphic subject' do
        Subscription.create!(base_attrs)
        Subscription.create!(base_attrs.merge(
                               subject_id: @workspace_two.id,
                               provider_subscription_id: SecureRandom.hex(8)
                             ))
        results = Subscription.for_subject(subject_type: @workspace_one.class.name,
                                           subject_id: @workspace_one.id)
        assert_equal 1, results.count
        assert_equal @workspace_one.id, results.first.subject_id
      end

      # --- DB-enforced partial unique index: one active/trialing per subject ---
      #
      # Index spec (created in Task 01):
      #   CREATE UNIQUE INDEX ON rsb_entitlements_subscriptions
      #     (subject_type, subject_id) WHERE status IN ('active','trialing');

      test 'partial unique: second active sub for same subject raises RecordNotUnique' do
        Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'a'))
        assert_raises(ActiveRecord::RecordNotUnique) do
          Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'b'))
        end
      end

      test 'partial unique: trialing also counts as a conflict' do
        Subscription.create!(base_attrs.merge(status: 'trialing', provider_subscription_id: 'a'))
        assert_raises(ActiveRecord::RecordNotUnique) do
          Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'b'))
        end
      end

      test 'partial unique: canceled sub does not count toward the cap' do
        Subscription.create!(base_attrs.merge(status: 'canceled', provider_subscription_id: 'a'))
        ok = Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'b'))
        assert ok.persisted?
      end

      test 'partial unique: incomplete/past_due/expired do not count toward the cap' do
        %w[incomplete past_due expired].each_with_index do |s, i|
          Subscription.create!(base_attrs.merge(
                                 status: s,
                                 provider_subscription_id: "noise_#{i}",
                                 # vary plan to avoid collisions if we add other indexes later
                                 plan_key: 'pro'
                               ))
        end
        ok = Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'live'))
        assert ok.persisted?
      end

      test 'partial unique: a different subject can have its own active sub' do
        Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'a'))
        ok = Subscription.create!(base_attrs.merge(
                                    status: 'active',
                                    subject_id: @workspace_two.id,
                                    provider_subscription_id: 'b'
                                  ))
        assert ok.persisted?
      end

      test 'partial unique: cancel-then-create-new flow succeeds' do
        first = Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'a'))
        first.update!(status: 'canceled')
        second = Subscription.create!(base_attrs.merge(status: 'active', provider_subscription_id: 'b'))
        assert second.persisted?
      end
    end
  end
end
