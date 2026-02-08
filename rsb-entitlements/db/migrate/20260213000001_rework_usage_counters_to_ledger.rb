class ReworkUsageCountersToLedger < ActiveRecord::Migration[8.0]
  def up
    # 1. Add new columns
    add_column :rsb_entitlements_usage_counters, :period_key, :string
    add_reference :rsb_entitlements_usage_counters, :plan,
                  null: true,
                  foreign_key: { to_table: :rsb_entitlements_plans }

    # 2. Data migration — set defaults for existing records
    #    All existing counters become cumulative records.
    #    Plan is set from the countable's most recent entitlement.
    execute <<~SQL
      UPDATE rsb_entitlements_usage_counters
      SET period_key = '__cumulative__',
          plan_id = (
            SELECT e.plan_id
            FROM rsb_entitlements_entitlements e
            WHERE e.entitleable_type = rsb_entitlements_usage_counters.countable_type
              AND e.entitleable_id = rsb_entitlements_usage_counters.countable_id
            ORDER BY e.created_at DESC
            LIMIT 1
          )
    SQL

    # 3. For any counters that still have NULL plan_id (no entitlement found),
    #    assign the first plan as a fallback
    fallback_plan_id = RSB::Entitlements::Plan.first&.id
    if fallback_plan_id
      execute <<~SQL
        UPDATE rsb_entitlements_usage_counters
        SET plan_id = #{fallback_plan_id}
        WHERE plan_id IS NULL
      SQL
    end

    # 4. Data migration — convert Plan.limits from flat to nested format
    RSB::Entitlements::Plan.find_each do |plan|
      next if plan.limits.blank?
      # Skip if already in nested format (first value is a Hash)
      first_value = plan.limits.values.first
      next if first_value.is_a?(Hash)

      nested = plan.limits.transform_values do |limit_value|
        { "limit" => limit_value, "period" => nil }
      end
      plan.update_column(:limits, nested)
    end

    # 5. Make columns NOT NULL now that data is migrated
    change_column_null :rsb_entitlements_usage_counters, :period_key, false
    change_column_null :rsb_entitlements_usage_counters, :plan_id, false

    # 6. Drop old columns
    remove_column :rsb_entitlements_usage_counters, :period, :string
    remove_column :rsb_entitlements_usage_counters, :period_start, :datetime
    remove_column :rsb_entitlements_usage_counters, :resets_at, :datetime

    # 7. Drop old unique index and create new one
    remove_index :rsb_entitlements_usage_counters,
                 name: "idx_rsb_usage_counters_unique"

    add_index :rsb_entitlements_usage_counters,
              [:countable_type, :countable_id, :metric, :period_key, :plan_id],
              unique: true,
              name: "idx_rsb_usage_counters_unique"

    # 8. Add supporting indexes
    add_index :rsb_entitlements_usage_counters, :metric,
              name: "idx_rsb_usage_counters_on_metric"
    add_index :rsb_entitlements_usage_counters, :period_key,
              name: "idx_rsb_usage_counters_on_period_key"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse usage counter ledger migration (data migration is lossy)"
  end
end
