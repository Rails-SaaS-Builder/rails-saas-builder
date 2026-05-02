# frozen_string_literal: true

class CreateRSBEntitlementsV1Tables < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:rsb_settings_settings)

    # ------------------------------------------------------------------
    # features — feature catalog (immutable key, kind enum, archive)
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_features do |t|
      t.text     :key,         null: false
      t.text     :name,        null: false
      t.text     :kind,        null: false
      t.text     :unit
      t.timestamptz :archived_at
      t.timestamptz :created_at, null: false, default: -> { 'now()' }
    end

    add_index :rsb_entitlements_features, :key, unique: true

    execute <<~SQL
      ALTER TABLE rsb_entitlements_features
        ADD CONSTRAINT rsb_entitlements_features_kind_check
        CHECK (kind IN ('flag', 'metered', 'gauge'))
    SQL

    execute <<~SQL
      ALTER TABLE rsb_entitlements_features
        ADD CONSTRAINT rsb_entitlements_features_key_format_check
        CHECK (key ~ '^[a-z0-9_]+(\.[a-z0-9_]+)*$')
    SQL

    # ------------------------------------------------------------------
    # plans — flat plans (no kind, no priority, no price)
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_plans do |t|
      t.text     :key,            null: false
      t.text     :name,           null: false
      t.integer  :display_order,  null: false, default: 0
      t.jsonb    :metadata,       null: false, default: {}
      t.timestamptz :archived_at
      t.timestamptz :created_at, null: false, default: -> { 'now()' }
    end

    add_index :rsb_entitlements_plans, :key, unique: true

    # ------------------------------------------------------------------
    # plan_features — grants (composition; hard-delete allowed)
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_plan_features do |t|
      t.text    :plan_key,    null: false
      t.text    :feature_key, null: false
      t.boolean :enabled
      t.bigint  :limit_value
      t.text    :period
    end

    add_index :rsb_entitlements_plan_features,
              %i[plan_key feature_key],
              unique: true,
              name: 'idx_rsb_ent_plan_features_unique'
    add_index :rsb_entitlements_plan_features, :feature_key,
              name: 'idx_rsb_ent_plan_features_on_feature_key'

    add_foreign_key :rsb_entitlements_plan_features, :rsb_entitlements_plans,
                    column: :plan_key, primary_key: :key
    add_foreign_key :rsb_entitlements_plan_features, :rsb_entitlements_features,
                    column: :feature_key, primary_key: :key

    execute <<~SQL
      ALTER TABLE rsb_entitlements_plan_features
        ADD CONSTRAINT rsb_entitlements_plan_features_period_check
        CHECK (period IS NULL OR period IN ('day', 'week', 'month', 'year'))
    SQL

    # ------------------------------------------------------------------
    # subscriptions — polymorphic subject; partial unique enforces
    # "one active subscription per subject"
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_subscriptions do |t|
      t.text    :subject_type,             null: false
      t.bigint  :subject_id,               null: false
      t.text    :plan_key,                 null: false
      t.text    :status,                   null: false
      t.timestamptz :current_period_start, null: false
      t.timestamptz :current_period_end,   null: false
      t.timestamptz :trial_end
      t.boolean :cancel_at_period_end, null: false, default: false
      t.timestamptz :canceled_at
      t.text    :provider,                 null: false
      t.text    :provider_subscription_id, null: false
      t.text    :provider_customer_id
      t.jsonb   :raw_state, null: false, default: {}
      t.timestamptz :created_at, null: false, default: -> { 'now()' }
      t.timestamptz :updated_at, null: false, default: -> { 'now()' }
    end

    # cross-system identity (unique upsert key)
    add_index :rsb_entitlements_subscriptions,
              %i[provider provider_subscription_id],
              unique: true,
              name: 'idx_rsb_ent_subs_provider_identity'

    # subject lookup
    add_index :rsb_entitlements_subscriptions,
              %i[subject_type subject_id status],
              name: 'idx_rsb_ent_subs_subject_status'

    # period-end scans (admin/jobs); partial keeps the index small
    add_index :rsb_entitlements_subscriptions, :current_period_end,
              where: "status IN ('active', 'trialing')",
              name: 'idx_rsb_ent_subs_period_end_active'

    # DB-enforced one-active-subscription-per-subject
    add_index :rsb_entitlements_subscriptions,
              %i[subject_type subject_id],
              unique: true,
              where: "status IN ('active', 'trialing')",
              name: 'idx_rsb_ent_subs_one_active_per_subject'

    add_foreign_key :rsb_entitlements_subscriptions, :rsb_entitlements_plans,
                    column: :plan_key, primary_key: :key

    execute <<~SQL
      ALTER TABLE rsb_entitlements_subscriptions
        ADD CONSTRAINT rsb_entitlements_subscriptions_status_check
        CHECK (status IN ('incomplete', 'trialing', 'active', 'past_due', 'canceled', 'expired'))
    SQL

    # ------------------------------------------------------------------
    # usage_counters — one row per (subject, feature); in-place period roll
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_usage_counters do |t|
      t.text    :subject_type, null: false
      t.bigint  :subject_id,   null: false
      t.text    :feature_key,  null: false
      t.timestamptz :period_start, null: false, default: -> { "'-infinity'::timestamptz" }
      t.bigint :consumed, null: false, default: 0
      t.timestamptz :updated_at, null: false, default: -> { 'now()' }
    end

    add_index :rsb_entitlements_usage_counters,
              %i[subject_type subject_id feature_key],
              unique: true,
              name: 'idx_rsb_ent_usage_counters_unique'

    add_foreign_key :rsb_entitlements_usage_counters, :rsb_entitlements_features,
                    column: :feature_key, primary_key: :key

    execute <<~SQL
      ALTER TABLE rsb_entitlements_usage_counters
        ADD CONSTRAINT rsb_entitlements_usage_counters_consumed_check
        CHECK (consumed >= 0)
    SQL

    # ------------------------------------------------------------------
    # provider_events — webhook idempotency log
    # ------------------------------------------------------------------
    create_table :rsb_entitlements_provider_events do |t|
      t.text  :provider, null: false
      t.text  :event_id, null: false
      t.text  :type,     null: false
      t.jsonb :payload,  null: false
      t.timestamptz :processed_at, null: false, default: -> { 'now()' }
    end

    add_index :rsb_entitlements_provider_events,
              %i[provider event_id],
              unique: true,
              name: 'idx_rsb_ent_provider_events_idempotency'
    add_index :rsb_entitlements_provider_events,
              %i[provider type],
              name: 'idx_rsb_ent_provider_events_provider_type'
  end
end
