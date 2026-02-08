class CreateRSBAuthSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_auth_sessions do |t|
      t.references :identity, null: false, foreign_key: { to_table: :rsb_auth_identities }
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_active_at
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :rsb_auth_sessions, :token, unique: true
    add_index :rsb_auth_sessions, :expires_at
  end
end
