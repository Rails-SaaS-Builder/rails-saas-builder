require "test_helper"

class RolePermissionsTest < ActiveSupport::TestCase
  test "permissions_checkboxes= converts hash to permissions format" do
    role = RSB::Admin::Role.new(name: "Test")
    role.permissions_checkboxes = {
      "rsb_auth_identities" => ["index", "show"],
      "rsb_entitlements_plans" => ["index", "show", "new", "create"]
    }

    expected = {
      "rsb_auth_identities" => ["index", "show"],
      "rsb_entitlements_plans" => ["index", "show", "new", "create"]
    }
    assert_equal expected, role.permissions
  end

  test "permissions_checkboxes= with blank params sets empty permissions" do
    role = RSB::Admin::Role.new(name: "Test", permissions: { "old" => ["data"] })
    role.permissions_checkboxes = nil

    assert_equal({}, role.permissions)
  end

  test "permissions_checkboxes= with empty hash sets empty permissions" do
    role = RSB::Admin::Role.new(name: "Test", permissions: { "old" => ["data"] })
    role.permissions_checkboxes = {}

    assert_equal({}, role.permissions)
  end

  test "permissions_checkboxes= rejects entries with empty action arrays" do
    role = RSB::Admin::Role.new(name: "Test")
    role.permissions_checkboxes = {
      "rsb_auth_identities" => ["index", "show"],
      "rsb_entitlements_plans" => []
    }

    # Should only have identities, not plans (since plans had empty actions)
    assert_equal({ "rsb_auth_identities" => ["index", "show"] }, role.permissions)
  end

  test "superadmin_toggle= with string '1' sets wildcard permissions" do
    role = RSB::Admin::Role.new(name: "Test")
    role.superadmin_toggle = "1"

    assert_equal({ "*" => ["*"] }, role.permissions)
    assert role.superadmin?
  end

  test "superadmin_toggle= with boolean true sets wildcard permissions" do
    role = RSB::Admin::Role.new(name: "Test")
    role.superadmin_toggle = true

    assert_equal({ "*" => ["*"] }, role.permissions)
    assert role.superadmin?
  end

  test "superadmin_toggle= with '0' does not override existing permissions" do
    role = RSB::Admin::Role.new(name: "Test", permissions: { "articles" => ["index"] })
    role.superadmin_toggle = "0"

    # Should keep the original permissions
    assert_equal({ "articles" => ["index"] }, role.permissions)
    refute role.superadmin?
  end

  test "superadmin_toggle= with nil does not override existing permissions" do
    role = RSB::Admin::Role.new(name: "Test", permissions: { "articles" => ["index"] })
    role.superadmin_toggle = nil

    # Should keep the original permissions
    assert_equal({ "articles" => ["index"] }, role.permissions)
    refute role.superadmin?
  end
end
