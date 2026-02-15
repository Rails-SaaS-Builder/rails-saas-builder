# frozen_string_literal: true

class CreateRSBEntitlementsPaymentRequests < ActiveRecord::Migration[8.0]
  def change
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
