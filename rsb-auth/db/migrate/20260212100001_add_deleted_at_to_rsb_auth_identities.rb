class AddDeletedAtToRSBAuthIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :rsb_auth_identities, :deleted_at, :datetime, null: true
    add_index :rsb_auth_identities, :deleted_at,
              where: "deleted_at IS NOT NULL",
              name: "index_rsb_auth_identities_on_deleted_at"
  end
end
