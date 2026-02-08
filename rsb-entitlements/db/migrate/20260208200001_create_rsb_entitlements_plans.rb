class CreateRSBEntitlementsPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :rsb_entitlements_plans do |t|
      t.string  :name,        null: false
      t.string  :slug,        null: false
      t.string  :interval,    null: false
      t.integer :price_cents, null: false, default: 0
      t.string  :currency,    null: false, default: "usd"
      t.json    :features,    default: {}
      t.json    :limits,      default: {}
      t.json    :metadata,    default: {}
      t.boolean :active,      default: true
      t.timestamps
    end

    add_index :rsb_entitlements_plans, :slug, unique: true
    add_index :rsb_entitlements_plans, :active
  end
end
