# frozen_string_literal: true

class AddProviderUidToRSBAuthCredentials < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:rsb_auth_credentials)

    unless column_exists?(:rsb_auth_credentials, :provider_uid)
      add_column :rsb_auth_credentials, :provider_uid, :string
    end

    unless index_exists?(:rsb_auth_credentials, [:type, :provider_uid], name: 'idx_rsb_auth_credentials_type_provider_uid')
      add_index :rsb_auth_credentials, [:type, :provider_uid],
                unique: true,
                where: 'provider_uid IS NOT NULL',
                name: 'idx_rsb_auth_credentials_type_provider_uid'
    end
  end
end
