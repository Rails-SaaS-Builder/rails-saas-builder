require "test_helper"

class TestHelperModuleTest < ActiveSupport::TestCase
  test "with_settings temporarily overrides and restores" do
    RSB::Settings.registry.define("demo") do
      setting :val, type: :string, default: "original"
    end

    assert_equal "original", RSB::Settings.get("demo.val")

    with_settings("demo.val" => "override") do
      assert_equal "override", RSB::Settings.get("demo.val")
    end

    # After with_settings block, original should be restored
    assert_equal "original", RSB::Settings.get("demo.val")
  end

  test "with_settings restores nil for settings that did not exist before" do
    RSB::Settings.registry.define("demo") do
      setting :new_key, type: :string
    end

    # new_key has nil default
    assert_nil RSB::Settings.get("demo.new_key")

    with_settings("demo.new_key" => "temp_value") do
      assert_equal "temp_value", RSB::Settings.get("demo.new_key")
    end

    # After block, the DB record should be removed (nil default again)
    assert_nil RSB::Settings.get("demo.new_key")
  end

  test "register_test_schema provides quick schema registration" do
    register_test_schema("quick", name: "default_name", count: 5, active: true)

    schema = RSB::Settings.registry.for("quick")
    assert_equal [:name, :count, :active], schema.keys

    # Verify types were inferred correctly
    name_def = schema.find(:name)
    assert_equal :string, name_def.type

    count_def = schema.find(:count)
    assert_equal :integer, count_def.type

    active_def = schema.find(:active)
    assert_equal :boolean, active_def.type
  end

  test "register_test_schema with float type" do
    register_test_schema("metrics", rate: 0.5)

    schema = RSB::Settings.registry.for("metrics")
    rate_def = schema.find(:rate)
    assert_equal :float, rate_def.type
    assert_equal 0.5, rate_def.default
  end

  test "teardown resets registry between tests" do
    # This test registers something. The next test should not see it.
    RSB::Settings.registry.define("teardown_test") { setting :x, type: :string }
    assert_includes RSB::Settings.registry.categories, "teardown_test"
  end

  test "teardown proof: previous test registry is clean" do
    # This test verifies the teardown from the previous test cleaned up
    refute_includes RSB::Settings.registry.categories, "teardown_test"
  end
end
