# frozen_string_literal: true

class CreateRSBAuthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_auth_identities do |t|
      t.string :status, null: false, default: 'active'
      t.json :metadata, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :rsb_auth_identities, :deleted_at,
              where: 'deleted_at IS NOT NULL',
              name: 'index_rsb_auth_identities_on_deleted_at'

    create_table :rsb_auth_credentials do |t|
      t.references :identity, null: false, foreign_key: { to_table: :rsb_auth_identities }
      t.string :type, null: false
      t.string :identifier, null: false
      t.string :password_digest, null: false
      t.json :metadata, default: {}
      t.datetime :verified_at
      t.string :verification_token
      t.datetime :verification_sent_at
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_until
      t.datetime :revoked_at
      t.string :recovery_email

      t.timestamps
    end

    add_index :rsb_auth_credentials, %i[type identifier],
              unique: true,
              where: 'revoked_at IS NULL',
              name: 'index_rsb_auth_credentials_on_type_and_identifier_active'
    add_index :rsb_auth_credentials, :verification_token, unique: true
    add_index :rsb_auth_credentials, :recovery_email

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

    create_table :rsb_auth_password_reset_tokens do |t|
      t.references :credential, null: false, foreign_key: { to_table: :rsb_auth_credentials }
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :rsb_auth_password_reset_tokens, :token, unique: true

    create_table :rsb_auth_invitations do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.references :invited_by, polymorphic: true, null: true
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :rsb_auth_invitations, :token, unique: true
    add_index :rsb_auth_invitations, :email
  end
end
