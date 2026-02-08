class CreateRSBAdminTables < ActiveRecord::Migration[8.0]
  def change
    create_table :rsb_admin_roles do |t|
      t.string :name, null: false
      t.json :permissions, null: false, default: {}
      t.boolean :built_in, default: false
      t.timestamps
    end

    add_index :rsb_admin_roles, :name, unique: true

    create_table :rsb_admin_admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.references :role, foreign_key: { to_table: :rsb_admin_roles }
      t.datetime :last_sign_in_at
      t.string :last_sign_in_ip
      t.string :pending_email
      t.string :email_verification_token
      t.datetime :email_verification_sent_at
      t.timestamps
    end

    add_index :rsb_admin_admin_users, :email, unique: true
    add_index :rsb_admin_admin_users, :email_verification_token, unique: true

    create_table :rsb_admin_admin_sessions do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :rsb_admin_admin_users }
      t.string :session_token, null: false
      t.string :ip_address
      t.text :user_agent
      t.string :browser
      t.string :os
      t.string :device_type
      t.datetime :last_active_at, null: false
      t.timestamps
    end

    add_index :rsb_admin_admin_sessions, :session_token, unique: true
  end
end
