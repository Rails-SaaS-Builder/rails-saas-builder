# frozen_string_literal: true

class CreateRSBAuthCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_auth_credentials do |t|
      t.references :identity, null: false, foreign_key: { to_table: :rsb_auth_identities }
      t.string :type, null: false
      t.string :identifier, null: false
      t.string :password_digest, null: false
      t.json :metadata, default: {}
      t.datetime :verified_at
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_until

      t.timestamps
    end

    add_index :rsb_auth_credentials, %i[type identifier], unique: true
  end
end
