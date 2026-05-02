# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class PlanFeatureTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        @plan          = Plan.create!(key: 'pro', name: 'Pro')
        @plan_archived = Plan.create!(key: 'old', name: 'Old', archived_at: 1.day.ago)
        @flag    = Feature.create!(key: 'sso',       name: 'SSO',       kind: 'flag')
        @metered = Feature.create!(key: 'api_calls', name: 'API calls', kind: 'metered', unit: 'count')
        @gauge   = Feature.create!(key: 'seats',     name: 'Seats',     kind: 'gauge',   unit: 'count')
        @feature_archived = Feature.create!(key: 'legacy', name: 'Legacy', kind: 'flag', archived_at: 1.day.ago)
      end

      # --- Associations ---

      test 'belongs_to :plan via plan_key → plans.key' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        assert_equal @plan, pf.plan
      end

      test 'belongs_to :feature via feature_key → features.key' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        assert_equal @flag, pf.feature
      end

      # --- Presence validations ---

      test 'requires plan_key' do
        pf = PlanFeature.new(feature_key: 'sso', enabled: true)
        refute pf.valid?
        assert_includes pf.errors[:plan_key], "can't be blank"
      end

      test 'requires feature_key' do
        pf = PlanFeature.new(plan_key: 'pro', enabled: true)
        refute pf.valid?
        assert_includes pf.errors[:feature_key], "can't be blank"
      end

      # --- Uniqueness (plan_key scoped to feature_key) ---

      test 'rejects duplicate (plan_key, feature_key) pair' do
        PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        dup = PlanFeature.new(plan_key: 'pro', feature_key: 'sso', enabled: false)
        refute dup.valid?
        assert_includes dup.errors[:plan_key], 'has already been taken'
      end

      test 'allows same feature_key under a different plan_key' do
        Plan.create!(key: 'free', name: 'Free')
        PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        pf = PlanFeature.create!(plan_key: 'free', feature_key: 'sso', enabled: false)
        assert_predicate pf, :persisted?
      end

      test 'allows same plan_key with a different feature_key' do
        Feature.create!(key: 'webhooks', name: 'Webhooks', kind: 'flag')
        PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'webhooks', enabled: true)
        assert_predicate pf, :persisted?
      end

      # --- referenced_records_not_archived ---

      test 'rejects create! when plan is archived' do
        err = assert_raises(ActiveRecord::RecordInvalid) do
          PlanFeature.create!(plan_key: 'old', feature_key: 'sso', enabled: true)
        end
        assert_includes err.record.errors[:plan_key].join(' '), 'archived'
      end

      test 'rejects create! when feature is archived' do
        err = assert_raises(ActiveRecord::RecordInvalid) do
          PlanFeature.create!(plan_key: 'pro', feature_key: 'legacy', enabled: true)
        end
        assert_includes err.record.errors[:feature_key].join(' '), 'archived'
      end

      test 'rejects update! when plan is later archived' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'api_calls',
                                 limit_value: 100, period: 'month')
        @plan.update!(archived_at: Time.current)
        err = assert_raises(ActiveRecord::RecordInvalid) { pf.update!(limit_value: 200) }
        assert_includes err.record.errors[:plan_key].join(' '), 'archived'
      end

      test 'rejects update! when feature is later archived' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        @flag.update!(archived_at: Time.current)
        err = assert_raises(ActiveRecord::RecordInvalid) { pf.update!(enabled: false) }
        assert_includes err.record.errors[:feature_key].join(' '), 'archived'
      end

      # --- grant_shape: flag ---

      test 'flag accepts enabled=true with no period or limit_value' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        assert_predicate pf, :persisted?
        assert_equal true, pf.enabled
      end

      test 'flag accepts enabled=false' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: false)
        assert_predicate pf, :persisted?
        assert_equal false, pf.enabled
      end

      test 'flag accepts enabled=nil (no validation forces it)' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: nil)
        assert_predicate pf, :persisted?
      end

      test 'flag does not validate period absence (period meaningless for flag, not invalid)' do
        # Per TDD §5 grant_shape rules: flag features ignore period & limit_value.
        # The model does not raise on stray values; the resolver simply does not
        # consult them. We verify here that an unexpected period stored on a
        # flag row does not block save.
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true, period: 'month')
        assert_predicate pf, :persisted?
      end

      # --- grant_shape: metered ---

      test 'metered accepts every valid period value' do
        %w[day week month year].each_with_index do |period, idx|
          feature_key = "metered_#{idx}"
          Feature.create!(key: feature_key, name: feature_key, kind: 'metered', unit: 'count')
          pf = PlanFeature.create!(plan_key: 'pro', feature_key: feature_key,
                                   limit_value: 100, period: period)
          assert_predicate pf, :persisted?, "expected period=#{period} to be accepted"
        end
      end

      test 'metered rejects nil period' do
        pf = PlanFeature.new(plan_key: 'pro', feature_key: 'api_calls', limit_value: 100, period: nil)
        refute pf.valid?
        assert_includes pf.errors[:period].join(' '), "can't be blank"
      end

      test 'metered rejects invalid period value' do
        pf = PlanFeature.new(plan_key: 'pro', feature_key: 'api_calls', limit_value: 100, period: 'hour')
        refute pf.valid?
        assert_includes pf.errors[:period].join(' '), 'is not included'
      end

      test 'metered allows nil limit_value (unlimited)' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'api_calls', limit_value: nil, period: 'month')
        assert_predicate pf, :persisted?
        assert_nil pf.limit_value
      end

      test 'metered create! with valid period and limit_value persists' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'api_calls', limit_value: 100, period: 'month')
        assert_predicate pf, :persisted?
        assert_equal 100, pf.limit_value
        assert_equal 'month', pf.period
      end

      # --- grant_shape: gauge ---

      test 'gauge rejects non-nil period on create!' do
        pf = PlanFeature.new(plan_key: 'pro', feature_key: 'seats', limit_value: 5, period: 'month')
        refute pf.valid?
        assert_includes pf.errors[:period].join(' '), 'must be blank'
      end

      test 'gauge rejects update! that introduces a period' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'seats', limit_value: 5)
        assert_raises(ActiveRecord::RecordInvalid) { pf.update!(period: 'month') }
      end

      test 'gauge accepts nil period and any limit_value (including nil)' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'seats', limit_value: 5, period: nil)
        assert_predicate pf, :persisted?
        assert_nil pf.period

        Feature.create!(key: 'storage', name: 'Storage', kind: 'gauge', unit: 'bytes')
        pf2 = PlanFeature.create!(plan_key: 'pro', feature_key: 'storage', limit_value: nil, period: nil)
        assert_predicate pf2, :persisted?
      end

      # --- destroy is allowed (mutable composition) ---

      test 'destroy succeeds without raising HardDeleteForbidden' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        # NOTE: usage_counters rows for the (subject, feature) pair intentionally
        # remain after grant destroy — they go stale-but-harmless and are no
        # longer drained. Counter cleanup is out of scope for v1 (see TDD-019
        # Edge Cases table).
        assert_nothing_raised { pf.destroy }
        refute PlanFeature.exists?(pf.id)
      end

      test 'destroy! also succeeds' do
        pf = PlanFeature.create!(plan_key: 'pro', feature_key: 'sso', enabled: true)
        assert_nothing_raised { pf.destroy! }
      end
    end
  end
end
