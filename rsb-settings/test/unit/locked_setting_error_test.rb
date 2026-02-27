# frozen_string_literal: true

require 'test_helper'

module RSB
  module Settings
    class LockedSettingErrorTest < ActiveSupport::TestCase
      test 'LockedSettingError is a StandardError subclass' do
        error = RSB::Settings::LockedSettingError.new('test')
        assert_kind_of StandardError, error
      end

      test 'LockedSettingError stores the message' do
        error = RSB::Settings::LockedSettingError.new("Setting 'auth.mode' is locked")
        assert_equal "Setting 'auth.mode' is locked", error.message
      end
    end

    class ResolverLockEnforcementTest < ActiveSupport::TestCase
      setup do
        RSB::Settings.reset!
        register_test_schema('auth', registration_mode: 'open', lockout_threshold: 5)
      end

      teardown do
        RSB::Settings.reset!
      end

      test 'set raises LockedSettingError when key is locked' do
        RSB::Settings.configure do |config|
          config.lock('auth.registration_mode')
        end

        error = assert_raises(RSB::Settings::LockedSettingError) do
          RSB::Settings.set('auth.registration_mode', 'disabled')
        end
        assert_equal "Setting 'auth.registration_mode' is locked", error.message
      end

      test 'set succeeds when key is NOT locked' do
        RSB::Settings.set('auth.registration_mode', 'invite_only')
        assert_equal 'invite_only', RSB::Settings.get('auth.registration_mode')
      end

      test 'set raises LockedSettingError and does not persist the value' do
        RSB::Settings.configure do |config|
          config.lock('auth.lockout_threshold')
        end

        assert_raises(RSB::Settings::LockedSettingError) do
          RSB::Settings.set('auth.lockout_threshold', 999)
        end

        # Value must remain at default (5), not the attempted 999
        assert_equal 5, RSB::Settings.get('auth.lockout_threshold')
      end

      test 'locking one key does not affect other keys' do
        RSB::Settings.configure do |config|
          config.lock('auth.registration_mode')
        end

        # This key is not locked — should succeed
        RSB::Settings.set('auth.lockout_threshold', 10)
        assert_equal 10, RSB::Settings.get('auth.lockout_threshold')
      end
    end
  end
end
