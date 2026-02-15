# frozen_string_literal: true

class AddMetadataToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :metadata, :json, default: {}
  end
end
