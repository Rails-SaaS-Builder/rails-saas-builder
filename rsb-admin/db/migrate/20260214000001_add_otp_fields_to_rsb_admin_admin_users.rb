class AddOtpFieldsToRSBAdminAdminUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :rsb_admin_admin_users, :otp_secret, :string
    add_column :rsb_admin_admin_users, :otp_required, :boolean, null: false, default: false
    add_column :rsb_admin_admin_users, :otp_backup_codes, :text
  end
end
