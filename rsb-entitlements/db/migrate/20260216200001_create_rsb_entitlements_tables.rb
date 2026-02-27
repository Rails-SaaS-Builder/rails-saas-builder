# frozen_string_literal: true

class CreateRSBEntitlementsTables < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_entitlements_plans do |t|
      t.string  :name,        null: false
      t.string  :slug,        null: false
      t.string  :interval,    null: false
      t.integer :price_cents, null: false, default: 0
      t.string  :currency,    null: false, default: 'usd'
      t.json    :features,    default: {}
      t.json    :limits,      default: {}
      t.json    :metadata,    default: {}
      t.boolean :active,      default: true

      t.timestamps
    end

    add_index :rsb_entitlements_plans, :slug, unique: true
    add_index :rsb_entitlements_plans, :active

    create_table :rsb_entitlements_entitlements do |t|
      t.references :entitleable, polymorphic: true, null: false
      t.references :plan, null: false, foreign_key: { to_table: :rsb_entitlements_plans }
      t.string   :status,       null: false, default: 'pending'
      t.string   :provider,     null: false
      t.string   :provider_ref
      t.datetime :activated_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.string   :revoke_reason
      t.json     :metadata, default: {}

      t.timestamps
    end

    add_index :rsb_entitlements_entitlements, :status
    add_index :rsb_entitlements_entitlements, :provider
    add_index :rsb_entitlements_entitlements, :expires_at

    create_table :rsb_entitlements_usage_counters do |t|
      t.references :countable, polymorphic: true, null: false
      t.string   :metric,        null: false
      t.integer  :current_value, null: false, default: 0
      t.integer  :limit
      t.string   :period_key, null: false
      t.references :plan, null: false, foreign_key: { to_table: :rsb_entitlements_plans }

      t.timestamps
    end

    add_index :rsb_entitlements_usage_counters,
              %i[countable_type countable_id metric period_key plan_id],
              unique: true,
              name: 'idx_rsb_usage_counters_unique'
    add_index :rsb_entitlements_usage_counters, :metric,
              name: 'idx_rsb_usage_counters_on_metric'
    add_index :rsb_entitlements_usage_counters, :period_key,
              name: 'idx_rsb_usage_counters_on_period_key'

    create_table :rsb_entitlements_payment_requests do |t|
      t.references :requestable, polymorphic: true, null: false
      t.references :plan, null: false, foreign_key: { to_table: :rsb_entitlements_plans }
      t.references :entitlement, null: true, foreign_key: { to_table: :rsb_entitlements_entitlements }
      t.string   :provider_key,  null: false
      t.string   :status,        null: false, default: 'pending'
      t.integer  :amount_cents,  null: false, default: 0
      t.string   :currency,      null: false, default: 'usd'
      t.string   :provider_ref
      t.json     :provider_data, default: {}
      t.text     :admin_note
      t.string   :resolved_by
      t.datetime :resolved_at
      t.datetime :expires_at
      t.json     :metadata, default: {}

      t.timestamps
    end

    add_index :rsb_entitlements_payment_requests,
              %i[requestable_type requestable_id],
              name: 'idx_payment_requests_on_requestable'
    add_index :rsb_entitlements_payment_requests, :status
    add_index :rsb_entitlements_payment_requests, :provider_key
    add_index :rsb_entitlements_payment_requests, :expires_at,
              where: "status IN ('pending', 'processing')",
              name: 'idx_payment_requests_on_expires_at'
    add_index :rsb_entitlements_payment_requests,
              %i[requestable_type requestable_id plan_id],
              unique: true,
              where: "status IN ('pending', 'processing')",
              name: 'idx_payment_requests_actionable_unique'
  end
end
