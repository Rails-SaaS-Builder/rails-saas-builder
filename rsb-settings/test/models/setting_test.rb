# frozen_string_literal: true

require 'test_helper'

module RSB
  module Settings
    class SettingTest < ActiveSupport::TestCase
      test 'get returns nil for non-existent setting' do
        assert_nil RSB::Settings::Setting.get('auth', 'nonexistent')
      end

      test 'set creates a new setting record' do
        RSB::Settings::Setting.set('auth', 'mode', 'open')

        record = RSB::Settings::Setting.find_by(category: 'auth', key: 'mode')
        assert_not_nil record
        assert_equal 'open', record.value
      end

      test 'set updates existing setting' do
        RSB::Settings::Setting.set('auth', 'mode', 'open')
        RSB::Settings::Setting.set('auth', 'mode', 'closed')

        assert_equal 1, RSB::Settings::Setting.where(category: 'auth', key: 'mode').count
        assert_equal 'closed', RSB::Settings::Setting.get('auth', 'mode')
      end

      test 'validates presence of category' do
        record = RSB::Settings::Setting.new(key: 'mode', value: 'open')
        refute record.valid?
        assert_includes record.errors[:category], "can't be blank"
      end

      test 'validates presence of key' do
        record = RSB::Settings::Setting.new(category: 'auth', value: 'open')
        refute record.valid?
        assert_includes record.errors[:key], "can't be blank"
      end

      test 'validates uniqueness of key within category' do
        RSB::Settings::Setting.set('auth', 'mode', 'open')

        duplicate = RSB::Settings::Setting.new(category: 'auth', key: 'mode', value: 'other')
        refute duplicate.valid?
      end

      test 'same key in different categories is allowed' do
        RSB::Settings::Setting.set('auth', 'timeout', '30')
        RSB::Settings::Setting.set('billing', 'timeout', '60')

        assert_equal '30', RSB::Settings::Setting.get('auth', 'timeout')
        assert_equal '60', RSB::Settings::Setting.get('billing', 'timeout')
      end

      test 'for_category scope filters by category' do
        RSB::Settings::Setting.set('auth', 'a', '1')
        RSB::Settings::Setting.set('auth', 'b', '2')
        RSB::Settings::Setting.set('billing', 'c', '3')

        auth_settings = RSB::Settings::Setting.for_category('auth')
        assert_equal 2, auth_settings.count
        assert(auth_settings.all? { |s| s.category == 'auth' })
      end

      test 'encrypts value (stored encrypted, read decrypted)' do
        RSB::Settings::Setting.set('auth', 'secret', 'my_secret_value')

        record = RSB::Settings::Setting.find_by(category: 'auth', key: 'secret')
        assert_equal 'my_secret_value', record.value

        # The raw database value should be different from the plaintext
        raw_value = ActiveRecord::Base.connection.select_value(
          "SELECT value FROM rsb_settings_settings WHERE category = 'auth' AND key = 'secret'"
        )
        refute_equal 'my_secret_value', raw_value
      end

      test 'uses rsb_settings_settings table' do
        assert_equal 'rsb_settings_settings', RSB::Settings::Setting.table_name
      end
    end
  end
end
