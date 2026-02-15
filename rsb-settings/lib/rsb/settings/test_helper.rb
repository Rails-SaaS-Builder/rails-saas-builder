# frozen_string_literal: true

module RSB
  module Settings
    module TestHelper
      extend ActiveSupport::Concern

      included do
        teardown do
          RSB::Settings.reset!
          RSB::Settings::Setting.delete_all if RSB::Settings::Setting.table_exists?
        end
      end

      # Temporarily override settings within a block
      def with_settings(overrides = {})
        originals = {}
        overrides.each do |key, value|
          originals[key] = begin
            RSB::Settings.get(key)
          rescue StandardError
            nil
          end
          RSB::Settings.set(key, value)
        end
        yield
      ensure
        originals.each do |key, value|
          category, setting_key = key.to_s.split('.', 2)
          if value.nil?
            RSB::Settings::Setting.find_by(category: category, key: setting_key)&.destroy
            # Invalidate cache so the resolver picks up the deletion
            RSB::Settings.send(:resolver).invalidate(category, setting_key)
          else
            RSB::Settings.set(key, value)
          end
        end
      end

      # Register a test schema quickly
      def register_test_schema(category, **settings)
        RSB::Settings.registry.define(category) do
          settings.each do |key, default|
            type = case default
                   when Integer then :integer
                   when true, false then :boolean
                   when Float then :float
                   when Symbol then :symbol
                   when Array then :array
                   else :string
                   end
            setting key, type: type, default: default
          end
        end
      end
    end
  end
end
