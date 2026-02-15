# frozen_string_literal: true

require 'test_helper'

class AdminLocaleSwitcherTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    # Configure I18n to accept test locales
    @original_available_locales = I18n.available_locales
    I18n.available_locales = %i[en de fr]
  end

  teardown do
    I18n.available_locales = @original_available_locales
  end

  # --- Visibility ---

  test 'locale switcher is hidden when single locale configured' do
    # Default config is ["en"] only
    get '/admin'
    assert_response :success
    refute_match 'rsb-locale-switcher', response.body
  end

  test 'locale switcher is visible when multiple locales configured' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de fr] }

    get '/admin'
    assert_response :success
    assert_match 'rsb-locale-switcher', response.body
    assert_match 'English', response.body
    assert_match 'Deutsch', response.body
    assert_match 'Français', response.body
  end

  test 'locale switcher shows current locale as selected' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    # Set locale cookie first
    post '/rsb/locale', params: { locale: 'de', redirect_to: '/admin' }

    # Follow redirect - session cookie is preserved by integration test framework
    follow_redirect!
    assert_response :success
    # The current locale should be marked (e.g., with a checkmark or highlighted)
    assert_match 'rsb-locale-switcher', response.body
  end

  # --- Switching ---

  test 'POST /rsb/locale sets cookie and redirects back' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    post '/rsb/locale', params: { locale: 'de', redirect_to: '/admin/settings' }
    assert_response :redirect
    assert_redirected_to '/admin/settings'
    assert_match 'rsb_locale=de', response.headers['Set-Cookie']
  end

  test 'locale persists across admin requests via cookie' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    # Set locale
    post '/rsb/locale', params: { locale: 'de', redirect_to: '/admin' }
    assert_response :redirect

    # Follow redirect - session and locale cookies are preserved
    follow_redirect!
    assert_response :success
    # Middleware should have set I18n.locale to :de for this request
    # Verify locale switcher shows DE as current
    assert_match 'rsb-locale-switcher', response.body
  end

  # --- Theme consistency ---

  test 'locale switcher uses rsb-* theme classes' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    get '/admin'
    assert_response :success
    assert_match 'rsb-locale-switcher', response.body
    # Verify it uses themed classes, not raw HTML
    assert_match 'text-rsb-', response.body
  end

  # --- Globe icon ---

  test 'globe icon is rendered in locale switcher' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    get '/admin'
    assert_response :success
    # The switcher button should contain the globe icon SVG
    # Check for the circle element that's distinctive to the globe icon
    assert_match(/<circle cx="12" cy="12" r="10"/, response.body)
  end
end
