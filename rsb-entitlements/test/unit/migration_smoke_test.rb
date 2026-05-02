# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class MigrationSmokeTest < ActiveSupport::TestCase
      def connection
        ActiveRecord::Base.connection
      end

      def column(table, name)
        connection.columns(table).find { |c| c.name == name.to_s }
      end

      def indexes(table)
        connection.indexes(table)
      end

      # --- features ---

      test 'rsb_entitlements_features table exists' do
        assert_includes connection.tables, 'rsb_entitlements_features'
      end

      test 'rsb_entitlements_features has required columns' do
        %w[id key name kind unit archived_at created_at].each do |col|
          assert column('rsb_entitlements_features', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_features.key is unique' do
        idx = indexes('rsb_entitlements_features').find { |i| i.columns == ['key'] }
        assert idx, 'expected unique index on features.key'
        assert idx.unique, 'expected features.key index to be unique'
      end

      test 'rsb_entitlements_features.kind is non-null' do
        refute column('rsb_entitlements_features', 'kind').null
      end

      test 'rsb_entitlements_features has CHECK on kind' do
        result = connection.execute(<<~SQL).to_a
          SELECT pg_get_constraintdef(c.oid) AS def
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          WHERE t.relname = 'rsb_entitlements_features'
            AND c.contype = 'c'
        SQL
        assert result.any? { |row| row['def'].include?('kind') && row['def'].include?('flag') },
               'expected CHECK constraint on features.kind'
      end

      # --- plans ---

      test 'rsb_entitlements_plans table exists' do
        assert_includes connection.tables, 'rsb_entitlements_plans'
      end

      test 'rsb_entitlements_plans has required columns' do
        %w[id key name display_order metadata archived_at created_at].each do |col|
          assert column('rsb_entitlements_plans', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_plans.key is unique' do
        idx = indexes('rsb_entitlements_plans').find { |i| i.columns == ['key'] }
        assert idx&.unique, 'expected unique index on plans.key'
      end

      test 'rsb_entitlements_plans.metadata defaults to empty jsonb' do
        col = column('rsb_entitlements_plans', 'metadata')
        assert_equal 'jsonb', col.sql_type
        assert col.default.to_s.include?('{}')
      end

      # --- plan_features ---

      test 'rsb_entitlements_plan_features table exists' do
        assert_includes connection.tables, 'rsb_entitlements_plan_features'
      end

      test 'rsb_entitlements_plan_features has required columns' do
        %w[id plan_key feature_key enabled limit_value period].each do |col|
          assert column('rsb_entitlements_plan_features', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_plan_features has unique (plan_key, feature_key)' do
        idx = indexes('rsb_entitlements_plan_features')
              .find { |i| i.columns == %w[plan_key feature_key] }
        assert idx&.unique, 'expected unique composite index'
      end

      test 'rsb_entitlements_plan_features has FK to plans(key)' do
        fks = connection.foreign_keys('rsb_entitlements_plan_features')
        fk = fks.find { |f| f.column == 'plan_key' }
        assert fk, 'expected FK on plan_key'
        assert_equal 'rsb_entitlements_plans', fk.to_table
      end

      test 'rsb_entitlements_plan_features has FK to features(key)' do
        fks = connection.foreign_keys('rsb_entitlements_plan_features')
        fk = fks.find { |f| f.column == 'feature_key' }
        assert fk, 'expected FK on feature_key'
        assert_equal 'rsb_entitlements_features', fk.to_table
      end

      test 'rsb_entitlements_plan_features has CHECK on period' do
        result = connection.execute(<<~SQL).to_a
          SELECT pg_get_constraintdef(c.oid) AS def
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          WHERE t.relname = 'rsb_entitlements_plan_features'
            AND c.contype = 'c'
        SQL
        assert result.any? { |row| row['def'].include?('period') && row['def'].include?('day') },
               'expected CHECK constraint on plan_features.period'
      end

      # --- subscriptions ---

      test 'rsb_entitlements_subscriptions table exists' do
        assert_includes connection.tables, 'rsb_entitlements_subscriptions'
      end

      test 'rsb_entitlements_subscriptions has required columns' do
        %w[id subject_type subject_id plan_key status
           current_period_start current_period_end trial_end
           cancel_at_period_end canceled_at provider provider_subscription_id
           provider_customer_id raw_state created_at updated_at].each do |col|
          assert column('rsb_entitlements_subscriptions', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_subscriptions has unique (provider, provider_subscription_id)' do
        idx = indexes('rsb_entitlements_subscriptions')
              .find { |i| i.columns == %w[provider provider_subscription_id] }
        assert idx&.unique, 'expected unique cross-system identity index'
      end

      test 'rsb_entitlements_subscriptions has partial unique on (subject_type, subject_id) for active+trialing' do
        idx = indexes('rsb_entitlements_subscriptions')
              .find { |i| i.columns == %w[subject_type subject_id] && i.unique }
        assert idx, 'expected partial unique on subject for active subscriptions'
        assert idx.where.to_s.include?('active'), "expected WHERE clause referencing 'active' status"
      end

      test 'rsb_entitlements_subscriptions has index on (subject_type, subject_id, status)' do
        idx = indexes('rsb_entitlements_subscriptions')
              .find { |i| i.columns == %w[subject_type subject_id status] }
        assert idx, 'expected lookup index'
      end

      test 'rsb_entitlements_subscriptions has partial index on current_period_end' do
        idx = indexes('rsb_entitlements_subscriptions')
              .find { |i| i.columns == ['current_period_end'] }
        assert idx, 'expected current_period_end index'
        assert idx.where.to_s.include?('active'), 'expected partial WHERE clause'
      end

      test 'rsb_entitlements_subscriptions has FK to plans(key)' do
        fks = connection.foreign_keys('rsb_entitlements_subscriptions')
        fk = fks.find { |f| f.column == 'plan_key' }
        assert fk, 'expected FK on plan_key'
        assert_equal 'rsb_entitlements_plans', fk.to_table
      end

      test 'rsb_entitlements_subscriptions has CHECK on status' do
        result = connection.execute(<<~SQL).to_a
          SELECT pg_get_constraintdef(c.oid) AS def
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          WHERE t.relname = 'rsb_entitlements_subscriptions'
            AND c.contype = 'c'
        SQL
        assert result.any? { |row| row['def'].include?('status') && row['def'].include?('active') },
               'expected CHECK constraint on subscriptions.status'
      end

      # --- usage_counters ---

      test 'rsb_entitlements_usage_counters table exists' do
        assert_includes connection.tables, 'rsb_entitlements_usage_counters'
      end

      test 'rsb_entitlements_usage_counters has required columns' do
        %w[id subject_type subject_id feature_key period_start consumed updated_at].each do |col|
          assert column('rsb_entitlements_usage_counters', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_usage_counters has unique (subject_type, subject_id, feature_key)' do
        idx = indexes('rsb_entitlements_usage_counters')
              .find { |i| i.columns == %w[subject_type subject_id feature_key] }
        assert idx&.unique, 'expected unique composite index for upsert'
      end

      test 'rsb_entitlements_usage_counters has FK to features(key)' do
        fks = connection.foreign_keys('rsb_entitlements_usage_counters')
        fk = fks.find { |f| f.column == 'feature_key' }
        assert fk, 'expected FK on feature_key'
        assert_equal 'rsb_entitlements_features', fk.to_table
      end

      test 'rsb_entitlements_usage_counters has CHECK consumed >= 0' do
        result = connection.execute(<<~SQL).to_a
          SELECT pg_get_constraintdef(c.oid) AS def
          FROM pg_constraint c
          JOIN pg_class t ON t.oid = c.conrelid
          WHERE t.relname = 'rsb_entitlements_usage_counters'
            AND c.contype = 'c'
        SQL
        assert result.any? { |row| row['def'].include?('consumed') && row['def'].include?('>= 0') },
               'expected CHECK constraint on usage_counters.consumed'
      end

      # --- provider_events ---

      test 'rsb_entitlements_provider_events table exists' do
        assert_includes connection.tables, 'rsb_entitlements_provider_events'
      end

      test 'rsb_entitlements_provider_events has required columns' do
        %w[id provider event_id type payload processed_at].each do |col|
          assert column('rsb_entitlements_provider_events', col), "missing column #{col}"
        end
      end

      test 'rsb_entitlements_provider_events has unique (provider, event_id)' do
        idx = indexes('rsb_entitlements_provider_events')
              .find { |i| i.columns == %w[provider event_id] }
        assert idx&.unique, 'expected unique idempotency index'
      end

      test 'rsb_entitlements_provider_events has index on (provider, type)' do
        idx = indexes('rsb_entitlements_provider_events')
              .find { |i| i.columns == %w[provider type] }
        assert idx, 'expected admin filter index'
      end
    end
  end
end
