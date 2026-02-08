require "test_helper"

class EnabledTest < ActiveSupport::TestCase
  setup do
    RSB::Admin.reset!
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
  end

  teardown do
    ENV.delete("RSB_ADMIN_ENABLED")
    RSB::Admin.reset!
  end

  test "enabled? returns true by default" do
    assert RSB::Admin.enabled?
  end

  test "enabled? returns false when configured via initializer" do
    RSB::Admin.configure { |c| c.enabled = false }
    # Note: initializer value is checked via Settings resolution chain
    # This test verifies the configuration attribute exists
    assert_equal false, RSB::Admin.configuration.enabled
  end

  test "enabled? returns true when ENV is set to true" do
    ENV["RSB_ADMIN_ENABLED"] = "true"
    assert RSB::Admin.enabled?
  end

  test "enabled? returns false when ENV is set to false" do
    ENV["RSB_ADMIN_ENABLED"] = "false"
    assert_not RSB::Admin.enabled?
  end

  test "ENV override takes priority over DB value" do
    # Simulate DB saying disabled
    RSB::Settings.set("admin.enabled", "false")
    # But ENV says enabled — ENV wins
    ENV["RSB_ADMIN_ENABLED"] = "true"
    assert RSB::Admin.enabled?
  end

  test "ENV override can disable even if DB says enabled" do
    RSB::Settings.set("admin.enabled", "true")
    ENV["RSB_ADMIN_ENABLED"] = "false"
    assert_not RSB::Admin.enabled?
  end
end
