class AddRecoveryEmailToRSBAuthCredentials < ActiveRecord::Migration[8.0]
  def change
    add_column :rsb_auth_credentials, :recovery_email, :string
    add_index :rsb_auth_credentials, :recovery_email
  end
end
