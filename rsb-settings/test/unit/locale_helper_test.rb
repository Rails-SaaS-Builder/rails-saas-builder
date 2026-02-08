require "test_helper"
require "action_view"
require "action_view/test_case"

class LocaleHelperTest < ActionView::TestCase
  include RSB::Settings::LocaleHelper

  setup do
    RSB::Settings.reset!
  end

  test "rsb_available_locales returns configured locales" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    assert_equal %w[en de], rsb_available_locales
  end

  test "rsb_current_locale returns I18n.locale as string" do
    original_locale = I18n.locale
    original_available = I18n.available_locales

    I18n.available_locales = [:en, :de]
    I18n.locale = :de
    assert_equal "de", rsb_current_locale
  ensure
    I18n.locale = original_locale
    I18n.available_locales = original_available
  end

  test "rsb_locale_display_name returns native name" do
    assert_equal "Deutsch", rsb_locale_display_name("de")
  end

  test "rsb_locale_switcher returns empty string when single locale" do
    RSB::Settings.configure { |c| c.available_locales = %w[en] }
    assert_equal "", rsb_locale_switcher(current_path: "/test")
  end

  test "rsb_locale_switcher returns HTML when multiple locales" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    html = rsb_locale_switcher(current_path: "/test")
    assert html.html_safe?
    assert_match "/rsb/locale", html
    assert_match "English", html
    assert_match "Deutsch", html
    assert_match "redirect_to", html
    assert_match "/test", html
  end
end
