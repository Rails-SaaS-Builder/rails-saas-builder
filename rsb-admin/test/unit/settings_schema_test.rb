require "test_helper"

class SettingsSchemaTest < ActiveSupport::TestCase
  test "build returns a valid Schema with category admin" do
    schema = RSB::Admin::SettingsSchema.build
    assert schema.valid?
    assert_equal "admin", schema.category
  end

  test "schema keys include all expected settings" do
    schema = RSB::Admin::SettingsSchema.build
    expected = [:enabled, :app_name, :company_name, :logo_url, :footer_text, :theme, :per_page]
    expected.each do |key|
      assert_includes schema.keys, key, "Expected schema to include :#{key}"
    end
  end

  test "defines enabled setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:enabled)
    assert_not_nil defn
    assert_equal :boolean, defn.type
    assert_equal true, defn.default
  end

  test "defines app_name setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:app_name)
    assert_not_nil defn
    assert_equal :string, defn.type
    assert_equal "Admin", defn.default
  end

  test "defines company_name setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:company_name)
    assert_not_nil defn
    assert_equal :string, defn.type
    assert_equal "", defn.default
  end

  test "defines logo_url setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:logo_url)
    assert_not_nil defn
    assert_equal :string, defn.type
    assert_equal "", defn.default
  end

  test "defines footer_text setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:footer_text)
    assert_not_nil defn
    assert_equal :string, defn.type
    assert_equal "", defn.default
  end

  test "defines theme setting with dynamic enum" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:theme)
    assert_not_nil defn
    assert_equal :string, defn.type
    assert_equal "default", defn.default
    # Enum is a proc, not a static array
    assert defn.enum.respond_to?(:call), "theme enum should be a Proc"
    # Calling it returns registered theme keys
    enum_values = defn.enum.call
    assert_includes enum_values, "default"
    assert_includes enum_values, "modern"
  end

  test "theme enum reflects dynamically registered themes" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:theme)

    # Register a custom theme
    RSB::Admin.register_theme :custom_test,
      label: "Custom Test",
      css: "custom/test"

    enum_values = defn.enum.call
    assert_includes enum_values, "custom_test"
  ensure
    RSB::Admin.reset!
  end

  test "defines per_page setting" do
    schema = RSB::Admin::SettingsSchema.build
    defn = schema.find(:per_page)
    assert_not_nil defn
    assert_equal :integer, defn.type
    assert_equal 25, defn.default
  end

  test "admin settings have correct group assignments" do
    schema = RSB::Admin::SettingsSchema.build

    # Branding group
    assert_equal "Branding", schema.find(:app_name).group
    assert_equal "Branding", schema.find(:company_name).group
    assert_equal "Branding", schema.find(:logo_url).group
    assert_equal "Branding", schema.find(:footer_text).group

    # General group
    assert_equal "General", schema.find(:enabled).group
    assert_equal "General", schema.find(:theme).group
    assert_equal "General", schema.find(:per_page).group
  end
end
