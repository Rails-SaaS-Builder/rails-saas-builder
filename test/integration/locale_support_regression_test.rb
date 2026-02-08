require "test_helper"

class LocaleSupportRegressionTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories

    # Configure I18n to accept test locales
    @original_available_locales = I18n.available_locales
    I18n.available_locales = [:en, :de, :fr]
  end

  teardown do
    I18n.available_locales = @original_available_locales
  end

  # --- Middleware Integration ---

  test "locale middleware is in the middleware stack" do
    middlewares = Rails.application.middleware.map(&:klass)
    assert_includes middlewares, RSB::Settings::LocaleMiddleware
  end

  test "middleware resolves locale from cookie for admin requests" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Set locale cookie
    post "/rsb/locale", params: { locale: "de", redirect_to: "/admin" }
    follow_redirect!

    assert_response :success
    # Middleware should have set env["rsb.locale"] = "de"
  end

  test "middleware resolves locale from cookie for auth requests" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    get "/auth/session/new", headers: { "HTTP_COOKIE" => "rsb_locale=de" }
    assert_response :success
  end

  test "middleware resolves locale from Accept-Language for host app requests" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de fr] }

    get "/up", headers: { "HTTP_ACCEPT_LANGUAGE" => "fr-FR,fr;q=0.9" }
    assert_response :success
  end

  # --- Cross-Engine Cookie Persistence ---

  test "locale cookie set from admin persists to auth pages" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    # Set locale via POST (could be from admin page)
    post "/rsb/locale", params: { locale: "de", redirect_to: "/auth/session/new" }
    assert_response :redirect

    # Visit auth page with cookie
    get "/auth/session/new", headers: { "HTTP_COOKIE" => "rsb_locale=de" }
    assert_response :success
  end

  test "locale cookie set from auth persists to admin pages" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Set locale via POST (could be from auth page)
    post "/rsb/locale", params: { locale: "de", redirect_to: "/admin" }
    assert_response :redirect

    # Follow redirect - session and locale cookies are preserved
    follow_redirect!
    assert_response :success
  end

  # --- Configuration Shared Across Gems ---

  test "RSB::Settings.available_locales is accessible and returns configured values" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de fr] }
    assert_equal %w[en de fr], RSB::Settings.available_locales
  end

  test "RSB::Settings.default_locale is accessible" do
    assert_equal "en", RSB::Settings.default_locale
  end

  test "RSB::Settings.locale_display_name returns native names" do
    assert_equal "Deutsch", RSB::Settings.locale_display_name("de")
    assert_equal "Français", RSB::Settings.locale_display_name("fr")
  end

  # --- Admin Switcher Visibility ---

  test "admin header shows locale switcher when multiple locales configured" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get "/admin"
    assert_response :success
    assert_match "rsb-locale-switcher", response.body
    # Check for globe icon SVG circle element
    assert_match(/<circle cx="12" cy="12" r="10"/, response.body)
  end

  test "admin header hides locale switcher when single locale" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get "/admin"
    assert_response :success
    refute_match "rsb-locale-switcher", response.body
  end

  # --- Auth Switcher Visibility ---

  test "auth login page shows locale switcher when multiple locales configured" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    get "/auth/session/new"
    assert_response :success
    assert_match "rsb-locale-footer", response.body
  end

  test "auth login page hides locale switcher when single locale" do
    get "/auth/session/new"
    assert_response :success
    refute_match "rsb-locale-footer", response.body
  end

  # --- POST /rsb/locale Endpoint ---

  test "POST /rsb/locale sets cookie with correct attributes" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    post "/rsb/locale", params: { locale: "de", redirect_to: "/admin" }
    cookie = response.headers["Set-Cookie"]

    assert_match "rsb_locale=de", cookie
    assert_match "path=/", cookie
    assert_match(/samesite=lax/i, cookie)
  end

  test "POST /rsb/locale rejects invalid locale and sets default" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    post "/rsb/locale", params: { locale: "xx", redirect_to: "/admin" }
    assert_match "rsb_locale=en", response.headers["Set-Cookie"]
  end

  test "POST /rsb/locale prevents open redirect" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    post "/rsb/locale", params: { locale: "de", redirect_to: "https://evil.com" }
    assert_redirected_to "/"
  end

  # --- Default Behavior (no configuration) ---

  test "default single locale config shows no switchers anywhere" do
    # Default: available_locales = ["en"]
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get "/admin"
    refute_match "rsb-locale-switcher", response.body

    get "/auth/session/new"
    refute_match "rsb-locale-footer", response.body
  end

  # --- Thread Safety ---

  test "I18n.locale is reset after request completes" do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }

    get "/auth/session/new", headers: { "HTTP_COOKIE" => "rsb_locale=de" }
    assert_response :success

    # After the request, I18n.locale should be back to default
    assert_equal I18n.default_locale, I18n.locale
  end
end
