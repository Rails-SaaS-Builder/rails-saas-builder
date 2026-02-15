# frozen_string_literal: true

class CreateRSBEntitlementsUsageCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :rsb_entitlements_usage_counters do |t|
      t.references :countable, polymorphic: true, null: false
      t.string   :metric,        null: false
      t.integer  :current_value, null: false, default: 0
      t.integer  :limit
      t.string   :period
      t.datetime :period_start
      t.datetime :resets_at
      t.timestamps
    end

    add_index :rsb_entitlements_usage_counters,
              %i[countable_type countable_id metric],
              unique: true,
              name: 'idx_rsb_usage_counters_unique'
  end
end
