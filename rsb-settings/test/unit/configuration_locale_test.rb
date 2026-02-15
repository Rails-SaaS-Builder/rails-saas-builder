# frozen_string_literal: true

require 'test_helper'

class ConfigurationLocaleTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
  end

  # --- available_locales ---

  test "available_locales defaults to ['en']" do
    assert_equal ['en'], RSB::Settings.configuration.available_locales
  end

  test 'available_locales can be set via configure' do
    RSB::Settings.configure do |config|
      config.available_locales = %w[en de fr]
    end

    assert_equal %w[en de fr], RSB::Settings.configuration.available_locales
  end

  # --- default_locale ---

  test "default_locale defaults to 'en'" do
    assert_equal 'en', RSB::Settings.configuration.default_locale
  end

  test 'default_locale can be set via configure' do
    RSB::Settings.configure do |config|
      config.default_locale = 'de'
    end

    assert_equal 'de', RSB::Settings.configuration.default_locale
  end

  # --- locale_display_names ---

  test 'locale_display_names includes built-in names' do
    names = RSB::Settings.configuration.locale_display_names
    assert_equal 'English', names['en']
    assert_equal 'Deutsch', names['de']
    assert_equal 'Français', names['fr']
  end

  test 'locale_display_names merges custom names with built-in' do
    RSB::Settings.configure do |config|
      config.locale_display_names = { 'xx' => 'Custom Language' }
    end

    names = RSB::Settings.configuration.locale_display_names
    assert_equal 'English', names['en'] # built-in preserved
    assert_equal 'Custom Language', names['xx'] # custom added
  end

  test 'locale_display_names custom overrides built-in' do
    RSB::Settings.configure do |config|
      config.locale_display_names = { 'en' => 'American English' }
    end

    names = RSB::Settings.configuration.locale_display_names
    assert_equal 'American English', names['en']
  end

  # --- reset! clears locale config ---

  test 'reset! restores locale defaults' do
    RSB::Settings.configure do |config|
      config.available_locales = %w[en de]
      config.default_locale = 'de'
      config.locale_display_names = { 'xx' => 'Test' }
    end

    RSB::Settings.reset!

    assert_equal ['en'], RSB::Settings.configuration.available_locales
    assert_equal 'en', RSB::Settings.configuration.default_locale
    assert_nil RSB::Settings.configuration.locale_display_names['xx']
  end
end
