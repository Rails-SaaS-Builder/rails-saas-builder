require "test_helper"

class RSB::Settings::SettingsAPITest < ActiveSupport::TestCase
  test "get delegates to resolver and returns default" do
    RSB::Settings.registry.define("app") do
      setting :name, type: :string, default: "MyApp"
    end

    assert_equal "MyApp", RSB::Settings.get("app.name")
  end

  test "set persists value and get retrieves it" do
    RSB::Settings.registry.define("app") do
      setting :name, type: :string, default: "MyApp"
    end

    RSB::Settings.set("app.name", "NewApp")
    assert_equal "NewApp", RSB::Settings.get("app.name")
  end

  test "for returns hash of all settings in a category" do
    RSB::Settings.registry.define("app") do
      setting :name, type: :string, default: "MyApp"
      setting :port, type: :integer, default: 3000
    end

    result = RSB::Settings.for("app")
    assert_equal({ name: "MyApp", port: 3000 }, result)
  end

  test "reset! clears registry, resolver, and configuration" do
    RSB::Settings.registry.define("app") { setting :x, type: :string, default: "y" }
    RSB::Settings.configuration.lock("app.x")

    RSB::Settings.reset!

    assert_empty RSB::Settings.registry.categories
    refute RSB::Settings.configuration.locked?("app.x")
  end

  test "configure yields configuration object" do
    RSB::Settings.configure do |config|
      config.lock "test.key"
      config.set "test.value", "override"
    end

    assert RSB::Settings.configuration.locked?("test.key")
    assert_equal "override", RSB::Settings.configuration.initializer_value("test", "value")
  end

  test "registry is accessible" do
    assert_instance_of RSB::Settings::Registry, RSB::Settings.registry
  end

  test "configuration is accessible" do
    assert_instance_of RSB::Settings::Configuration, RSB::Settings.configuration
  end

  test "parse_key raises on bad format" do
    assert_raises(ArgumentError) { RSB::Settings.get("nodot") }
    assert_raises(ArgumentError) { RSB::Settings.set("nodot", "value") }
  end
end
