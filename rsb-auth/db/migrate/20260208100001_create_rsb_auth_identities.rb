class CreateRSBAuthIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :rsb_auth_identities do |t|
      t.string :status, null: false, default: "active"
      t.json :metadata, default: {}

      t.timestamps
    end
  end
end
