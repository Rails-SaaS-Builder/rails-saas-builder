# frozen_string_literal: true

class CreateRSBAuthPasswordResetTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_auth_password_reset_tokens do |t|
      t.references :credential, null: false, foreign_key: { to_table: :rsb_auth_credentials }
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :rsb_auth_password_reset_tokens, :token, unique: true
  end
end
