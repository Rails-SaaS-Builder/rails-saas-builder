# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class SettingsSchemaTest < ActiveSupport::TestCase
      test 'builds a valid RSB::Settings::Schema' do
        schema = RSB::Auth::SettingsSchema.build
        assert_instance_of RSB::Settings::Schema, schema
        assert schema.valid?
      end

      test "has category 'auth'" do
        schema = RSB::Auth::SettingsSchema.build
        assert_equal 'auth', schema.category
      end

      test 'contains all expected keys' do
        schema = RSB::Auth::SettingsSchema.build
        expected_keys = %i[
          registration_mode login_identifier password_min_length
          session_duration max_sessions lockout_threshold
          lockout_duration verification_required account_enabled
          account_deletion_enabled
        ]
        assert_equal expected_keys, schema.keys
      end

      test 'has correct defaults' do
        schema = RSB::Auth::SettingsSchema.build
        defaults = schema.defaults

        assert_equal 'open', defaults[:registration_mode]
        assert_equal 'email', defaults[:login_identifier]
        assert_equal 8, defaults[:password_min_length]
        assert_equal 86_400, defaults[:session_duration]
        assert_equal 5, defaults[:max_sessions]
        assert_equal 5, defaults[:lockout_threshold]
        assert_equal 900, defaults[:lockout_duration]
        assert_equal true, defaults[:verification_required]
        assert_equal true, defaults[:account_enabled]
        assert_equal true, defaults[:account_deletion_enabled]
      end

      test 'has correct types' do
        schema = RSB::Auth::SettingsSchema.build

        assert_equal :string, schema.find(:registration_mode).type
        assert_equal :string, schema.find(:login_identifier).type
        assert_equal :integer, schema.find(:password_min_length).type
        assert_equal :integer, schema.find(:session_duration).type
        assert_equal :integer, schema.find(:max_sessions).type
        assert_equal :integer, schema.find(:lockout_threshold).type
        assert_equal :integer, schema.find(:lockout_duration).type
        assert_equal :boolean, schema.find(:verification_required).type
        assert_equal :boolean, schema.find(:account_enabled).type
        assert_equal :boolean, schema.find(:account_deletion_enabled).type
      end

      test 'RSB::Auth.settings_schema returns the schema' do
        schema = RSB::Auth.settings_schema
        assert_instance_of RSB::Settings::Schema, schema
        assert_equal 'auth', schema.category
      end

      test 'auth settings have correct group assignments' do
        schema = RSB::Auth::SettingsSchema.build

        # Registration group
        assert_equal 'Registration', schema.find(:registration_mode).group
        assert_equal 'Registration', schema.find(:login_identifier).group
        assert_equal 'Registration', schema.find(:password_min_length).group
        assert_equal 'Registration', schema.find(:verification_required).group

        # Session & Security group
        assert_equal 'Session & Security', schema.find(:session_duration).group
        assert_equal 'Session & Security', schema.find(:max_sessions).group
        assert_equal 'Session & Security', schema.find(:lockout_threshold).group
        assert_equal 'Session & Security', schema.find(:lockout_duration).group

        # Features group
        assert_equal 'Features', schema.find(:account_enabled).group
        assert_equal 'Features', schema.find(:account_deletion_enabled).group
      end

      test 'account_deletion_enabled depends_on account_enabled' do
        schema = RSB::Auth::SettingsSchema.build

        acct_del = schema.find(:account_deletion_enabled)
        assert_equal 'auth.account_enabled', acct_del.depends_on

        # Master toggle should not have depends_on
        acct_enabled = schema.find(:account_enabled)
        assert_nil acct_enabled.depends_on
      end
    end
  end
end
