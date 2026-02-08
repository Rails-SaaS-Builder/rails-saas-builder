require "test_helper"

class SettingsLocaleApiTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
    RSB::Settings.configure do |config|
      config.available_locales = %w[en de fr]
      config.default_locale = "en"
    end
  end

  test "RSB::Settings.available_locales delegates to configuration" do
    assert_equal %w[en de fr], RSB::Settings.available_locales
  end

  test "RSB::Settings.default_locale delegates to configuration" do
    assert_equal "en", RSB::Settings.default_locale
  end

  test "RSB::Settings.locale_display_name returns native name for known code" do
    assert_equal "Deutsch", RSB::Settings.locale_display_name("de")
  end

  test "RSB::Settings.locale_display_name returns code string for unknown code" do
    assert_equal "xx", RSB::Settings.locale_display_name("xx")
  end

  test "RSB::Settings.locale_display_name accepts symbol" do
    assert_equal "English", RSB::Settings.locale_display_name(:en)
  end

  test "RSB::Settings.locale_display_names returns full mapping" do
    names = RSB::Settings.locale_display_names
    assert_instance_of Hash, names
    assert_equal "English", names["en"]
  end
end
