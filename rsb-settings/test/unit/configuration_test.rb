# frozen_string_literal: true

require 'test_helper'

module RSB
  module Settings
    class ConfigurationTest < ActiveSupport::TestCase
      test 'lock marks a setting as locked' do
        RSB::Settings.configure do |config|
          config.lock 'auth.registration_mode'
        end

        assert RSB::Settings.configuration.locked?('auth.registration_mode')
        refute RSB::Settings.configuration.locked?('auth.other')
      end

      test 'set stores initializer override' do
        RSB::Settings.configure do |config|
          config.set 'auth.mode', 'invite_only'
        end

        assert_equal 'invite_only', RSB::Settings.configuration.initializer_value('auth', 'mode')
      end

      test 'initializer_value returns nil for unset keys' do
        assert_nil RSB::Settings.configuration.initializer_value('auth', 'nonexistent')
      end

      test 'locked_keys returns all locked keys' do
        RSB::Settings.configure do |config|
          config.lock 'auth.a'
          config.lock 'auth.b'
        end

        assert_includes RSB::Settings.configuration.locked_keys, 'auth.a'
        assert_includes RSB::Settings.configuration.locked_keys, 'auth.b'
      end

      test 'locked? returns false by default' do
        refute RSB::Settings.configuration.locked?('anything')
      end

      test 'reset clears configuration' do
        RSB::Settings.configure do |config|
          config.lock 'auth.x'
          config.set 'auth.y', 'z'
        end

        RSB::Settings.reset!

        refute RSB::Settings.configuration.locked?('auth.x')
        assert_nil RSB::Settings.configuration.initializer_value('auth', 'y')
      end
    end
  end
end
