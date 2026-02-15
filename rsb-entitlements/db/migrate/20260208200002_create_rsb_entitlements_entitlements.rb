# frozen_string_literal: true

class CreateRSBEntitlementsEntitlements < ActiveRecord::Migration[8.0]
  def change
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
  end
end
