class AddVerificationToRSBAuthCredentials < ActiveRecord::Migration[8.1]
  def change
    add_column :rsb_auth_credentials, :verification_token, :string
    add_column :rsb_auth_credentials, :verification_sent_at, :datetime
    add_index :rsb_auth_credentials, :verification_token, unique: true
  end
end
