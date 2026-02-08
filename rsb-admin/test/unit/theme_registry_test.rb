require "test_helper"

class ThemeRegistryTest < ActiveSupport::TestCase
  setup do
    RSB::Admin.reset!
  end

  test "built-in themes are registered after reset" do
    assert_equal 2, RSB::Admin.themes.size
    assert RSB::Admin.themes[:default]
    assert RSB::Admin.themes[:modern]
  end

  test "default theme has correct attributes" do
    theme = RSB::Admin.themes[:default]
    assert_equal :default, theme.key
    assert_equal "Default", theme.label
    assert_equal "rsb/admin/themes/default", theme.css
    assert_nil theme.js
    assert_nil theme.views_path
  end

  test "modern theme has correct attributes" do
    theme = RSB::Admin.themes[:modern]
    assert_equal :modern, theme.key
    assert_equal "Modern", theme.label
    assert_equal "rsb/admin/themes/modern", theme.css
    assert_equal "rsb/admin/themes/modern", theme.js
    assert_equal "rsb/admin/themes/modern/views", theme.views_path
  end

  test "register_theme adds custom theme" do
    RSB::Admin.register_theme :corporate,
      label: "Corporate",
      css: "my_app/admin/corporate",
      views_path: "my_app/admin/corporate/views"

    assert_equal 3, RSB::Admin.themes.size
    theme = RSB::Admin.themes[:corporate]
    assert_equal :corporate, theme.key
    assert_equal "my_app/admin/corporate", theme.css
  end

  test "current_theme reads from settings DB" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    with_settings("admin.theme" => "modern") do
      assert_equal :modern, RSB::Admin.current_theme.key
    end
  end

  test "settings DB theme overrides configuration theme" do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    RSB::Admin.configuration.theme = :default
    with_settings("admin.theme" => "modern") do
      assert_equal :modern, RSB::Admin.current_theme.key
    end
  end

  test "current_theme falls back to configuration when settings not available" do
    RSB::Settings.reset!
    RSB::Admin.configuration.theme = :modern
    assert_equal :modern, RSB::Admin.current_theme.key
  end

  test "current_theme falls back to default when configured theme not found" do
    RSB::Settings.reset!
    RSB::Admin.configuration.theme = :nonexistent
    assert_equal :default, RSB::Admin.current_theme.key
  end

  test "reset! clears custom themes but keeps built-ins" do
    RSB::Admin.register_theme :custom, label: "Custom", css: "custom"
    assert_equal 3, RSB::Admin.themes.size

    RSB::Admin.reset!
    assert_equal 2, RSB::Admin.themes.size
    refute RSB::Admin.themes[:custom]
    assert RSB::Admin.themes[:default]
    assert RSB::Admin.themes[:modern]
  end

  test "Themes::Modern.register! registers the modern theme" do
    RSB::Admin.instance_variable_set(:@themes, {})
    RSB::Admin.register_theme :default, label: "Default", css: "rsb/admin/themes/default"

    assert_nil RSB::Admin.themes[:modern]
    RSB::Admin::Themes::Modern.register!
    assert RSB::Admin.themes[:modern]
    assert_equal "Modern", RSB::Admin.themes[:modern].label
    assert_equal "rsb/admin/themes/modern", RSB::Admin.themes[:modern].css
    assert_equal "rsb/admin/themes/modern", RSB::Admin.themes[:modern].js
    assert_equal "rsb/admin/themes/modern/views", RSB::Admin.themes[:modern].views_path
  end
end

class ConfigurationEnhancedTest < ActiveSupport::TestCase
  test "new defaults" do
    config = RSB::Admin::Configuration.new
    assert_equal :default, config.theme
    assert_nil config.view_overrides_path
    assert_equal "rsb/admin/application", config.layout
  end

  test "theme is configurable" do
    RSB::Admin.configure do |config|
      config.theme = :modern
      config.view_overrides_path = "my_app/admin/views"
      config.layout = "my_app/admin/layout"
    end

    assert_equal :modern, RSB::Admin.configuration.theme
    assert_equal "my_app/admin/views", RSB::Admin.configuration.view_overrides_path
    assert_equal "my_app/admin/layout", RSB::Admin.configuration.layout
  end
end
