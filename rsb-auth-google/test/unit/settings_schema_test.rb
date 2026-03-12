# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    module Google
      class SettingsSchemaTest < ActiveSupport::TestCase
        setup do
          register_all_settings
          register_all_credentials
        end

        test 'settings schema defines client_id setting' do
          schema = RSB::Auth::Google::SettingsSchema.build
          setting = schema.definitions.find { |d| d.key == :'credentials.google.client_id' }
          assert_not_nil setting, 'client_id setting must be defined'
          assert_equal :string, setting.type
          assert_equal '', setting.default
        end

        test 'settings schema defines client_secret setting' do
          schema = RSB::Auth::Google::SettingsSchema.build
          setting = schema.definitions.find { |d| d.key == :'credentials.google.client_secret' }
          assert_not_nil setting, 'client_secret setting must be defined'
          assert_equal :string, setting.type
          assert setting.encrypted, 'client_secret must be encrypted'
        end

        test 'settings schema defines auto_merge_by_email setting' do
          schema = RSB::Auth::Google::SettingsSchema.build
          setting = schema.definitions.find { |d| d.key == :'credentials.google.auto_merge_by_email' }
          assert_not_nil setting, 'auto_merge_by_email setting must be defined'
          assert_equal :boolean, setting.type
          assert_equal false, setting.default
        end

        test 'settings schema category is auth' do
          schema = RSB::Auth::Google::SettingsSchema.build
          assert_equal 'auth', schema.category
        end
      end
    end
  end
end
