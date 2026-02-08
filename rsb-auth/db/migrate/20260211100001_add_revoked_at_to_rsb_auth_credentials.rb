class AddRevokedAtToRSBAuthCredentials < ActiveRecord::Migration[8.1]
  def change
    add_column :rsb_auth_credentials, :revoked_at, :datetime, null: true

    # Replace full unique index with partial unique index scoped to active credentials.
    # This allows the same [type, identifier] to exist multiple times as long as
    # only one is active (revoked_at IS NULL). Supported by PostgreSQL and SQLite 3.8.0+.
    remove_index :rsb_auth_credentials, [:type, :identifier]
    add_index :rsb_auth_credentials, [:type, :identifier],
              unique: true,
              where: "revoked_at IS NULL",
              name: "index_rsb_auth_credentials_on_type_and_identifier_active"
  end
end
