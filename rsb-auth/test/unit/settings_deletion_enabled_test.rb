require "test_helper"

class RSB::Auth::SettingsDeletionEnabledTest < ActiveSupport::TestCase
  setup do
    register_auth_settings
  end

  test "account_deletion_enabled setting is registered in the schema" do
    schema = RSB::Auth::SettingsSchema.build
    assert schema.keys.include?(:account_deletion_enabled),
      "Expected schema to include :account_deletion_enabled key"
  end

  test "account_deletion_enabled defaults to true" do
    schema = RSB::Auth::SettingsSchema.build
    assert_equal true, schema.defaults[:account_deletion_enabled]
  end

  test "account_deletion_enabled has boolean type" do
    schema = RSB::Auth::SettingsSchema.build
    assert_equal :boolean, schema.find(:account_deletion_enabled).type
  end

  test "account_deletion_enabled is accessible via RSB::Settings.get" do
    value = RSB::Settings.get("auth.account_deletion_enabled")
    assert_equal true, value
  end
end
