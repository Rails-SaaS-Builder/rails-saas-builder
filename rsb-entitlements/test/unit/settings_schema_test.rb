require "test_helper"

class RSB::Entitlements::SettingsSchemaTest < ActiveSupport::TestCase
  test "builds a valid RSB::Settings::Schema" do
    schema = RSB::Entitlements::SettingsSchema.build
    assert_instance_of RSB::Settings::Schema, schema
    assert schema.valid?
  end

  test "has category 'entitlements'" do
    schema = RSB::Entitlements::SettingsSchema.build
    assert_equal "entitlements", schema.category
  end

  test "contains all expected keys" do
    schema = RSB::Entitlements::SettingsSchema.build
    expected_keys = [:default_currency, :trial_days, :grace_period_days, :auto_create_counters, :on_plan_change_usage, :payment_request_expiry_hours]
    assert_equal expected_keys, schema.keys
  end

  test "has correct defaults" do
    schema = RSB::Entitlements::SettingsSchema.build
    defaults = schema.defaults

    assert_equal "usd", defaults[:default_currency]
    assert_equal 14, defaults[:trial_days]
    assert_equal 3, defaults[:grace_period_days]
    assert_equal true, defaults[:auto_create_counters]
  end

  test "has correct types" do
    schema = RSB::Entitlements::SettingsSchema.build

    assert_equal :string, schema.find(:default_currency).type
    assert_equal :integer, schema.find(:trial_days).type
    assert_equal :integer, schema.find(:grace_period_days).type
    assert_equal :boolean, schema.find(:auto_create_counters).type
  end

  test "RSB::Entitlements.settings_schema returns the schema" do
    schema = RSB::Entitlements.settings_schema
    assert_instance_of RSB::Settings::Schema, schema
    assert_equal "entitlements", schema.category
  end

  test "entitlements settings have correct group assignments" do
    schema = RSB::Entitlements::SettingsSchema.build

    assert_equal "General", schema.find(:default_currency).group
    assert_equal "General", schema.find(:trial_days).group
    assert_equal "General", schema.find(:grace_period_days).group
    assert_equal "General", schema.find(:auto_create_counters).group
    assert_equal "General", schema.find(:on_plan_change_usage).group
    assert_equal "General", schema.find(:payment_request_expiry_hours).group
  end
end
