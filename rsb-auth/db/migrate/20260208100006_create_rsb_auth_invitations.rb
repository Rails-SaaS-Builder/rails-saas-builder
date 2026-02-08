class CreateRSBAuthInvitations < ActiveRecord::Migration[8.1]
  def change
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
