# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class SettingsSchemaTest < ActiveSupport::TestCase
      test 'build returns a Schema instance under category entitlements' do
        schema = SettingsSchema.build
        assert_instance_of RSB::Settings::Schema, schema
        assert_equal 'entitlements', schema.category
      end

      test 'schema registers no provider settings' do
        schema = SettingsSchema.build
        assert schema.definitions.none? { |s| s.key.to_s.start_with?('providers.') },
               'provider settings must live in adapter gems, not in core'
      end

      test 'schema does not register removed v0 keys' do
        schema = SettingsSchema.build
        keys = schema.definitions.map { |s| s.key.to_s }
        removed = %w[default_currency trial_days grace_period_days
                     auto_create_counters on_plan_change_usage
                     payment_request_expiry_hours]
        removed.each do |k|
          assert_not_includes keys, k, "expected v0 key #{k} to be removed"
        end
      end

      test 'schema is effectively empty in v1' do
        # Truly empty is the v1 default. If a future task adds an optional
        # setting, replace this with an explicit allowlist assertion.
        assert_equal 0, SettingsSchema.build.definitions.size
      end
    end
  end
end
