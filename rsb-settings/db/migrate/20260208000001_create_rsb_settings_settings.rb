# frozen_string_literal: true

class CreateRSBSettingsSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :rsb_settings_settings do |t|
      t.string :category, null: false
      t.string :key, null: false
      t.string :value
      t.timestamps
    end

    add_index :rsb_settings_settings, %i[category key], unique: true
    add_index :rsb_settings_settings, :category
  end
end
