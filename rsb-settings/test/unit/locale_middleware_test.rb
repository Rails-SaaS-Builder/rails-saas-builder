require "test_helper"
require "rack/mock"

class LocaleMiddlewareTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
    RSB::Settings.configure do |config|
      config.available_locales = %w[en de fr]
      config.default_locale = "en"
    end

    # Configure I18n to accept these locales
    @original_available_locales = I18n.available_locales
    I18n.available_locales = [:en, :de, :fr]

    @locale_during_request = nil
    @env_locale = nil
    @app = lambda do |env|
      @locale_during_request = I18n.locale
      @env_locale = env["rsb.locale"]
      [200, { "content-type" => "text/plain" }, ["OK"]]
    end
    @middleware = RSB::Settings::LocaleMiddleware.new(@app)
  end

  teardown do
    I18n.locale = I18n.default_locale
    I18n.available_locales = @original_available_locales
  end

  # --- Cookie-based resolution ---

  test "resolves locale from rsb_locale cookie" do
    env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "rsb_locale=de")
    @middleware.call(env)

    assert_equal :de, @locale_during_request
    assert_equal "de", @env_locale
  end

  test "ignores cookie with unavailable locale and falls back to default" do
    env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "rsb_locale=xx")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end

  test "ignores empty cookie" do
    env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "rsb_locale=")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end

  # --- Accept-Language resolution ---

  test "resolves locale from Accept-Language header when no cookie" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT_LANGUAGE" => "de-DE,de;q=0.9,en;q=0.8")
    @middleware.call(env)

    assert_equal :de, @locale_during_request
  end

  test "picks highest quality match from Accept-Language" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT_LANGUAGE" => "es;q=0.5,fr;q=0.9,de;q=0.7")
    @middleware.call(env)

    assert_equal :fr, @locale_during_request
  end

  test "falls back to default when Accept-Language has no available locales" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT_LANGUAGE" => "es,pt;q=0.9")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end

  test "handles malformed Accept-Language gracefully" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT_LANGUAGE" => ";;;garbage")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end

  test "handles missing Accept-Language" do
    env = Rack::MockRequest.env_for("/")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end

  # --- Cookie takes priority over Accept-Language ---

  test "cookie takes priority over Accept-Language" do
    env = Rack::MockRequest.env_for(
      "/",
      "HTTP_COOKIE" => "rsb_locale=fr",
      "HTTP_ACCEPT_LANGUAGE" => "de-DE,de;q=0.9"
    )
    @middleware.call(env)

    assert_equal :fr, @locale_during_request
  end

  # --- I18n.locale is reset after request ---

  test "resets I18n.locale after request" do
    env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "rsb_locale=de")
    @middleware.call(env)

    assert_equal I18n.default_locale, I18n.locale
  end

  test "resets I18n.locale even when app raises" do
    error_app = lambda { |_env| raise "boom" }
    middleware = RSB::Settings::LocaleMiddleware.new(error_app)
    env = Rack::MockRequest.env_for("/", "HTTP_COOKIE" => "rsb_locale=de")

    assert_raises(RuntimeError) { middleware.call(env) }
    assert_equal I18n.default_locale, I18n.locale
  end

  # --- POST /rsb/locale ---

  test "POST /rsb/locale sets cookie and redirects to redirect_to param" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=de&redirect_to=/admin/settings",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_equal "/admin/settings", headers["location"]
    assert_match "rsb_locale=de", headers["set-cookie"]
  end

  test "POST /rsb/locale falls back to Referer for redirect" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=fr",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "HTTP_REFERER" => "http://localhost:3000/auth/session/new"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_equal "/auth/session/new", headers["location"]
  end

  test "POST /rsb/locale falls back to / when no redirect_to or Referer" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=de",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_equal "/", headers["location"]
  end

  test "POST /rsb/locale sanitizes redirect_to to prevent open redirect" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=de&redirect_to=https://evil.com/phish",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_equal "/", headers["location"]
  end

  test "POST /rsb/locale with unavailable locale falls back to default" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=xx&redirect_to=/admin",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_match "rsb_locale=en", headers["set-cookie"]
  end

  test "POST /rsb/locale with empty locale redirects without setting cookie" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=&redirect_to=/admin",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    status, headers, _body = @middleware.call(env)

    assert_equal 302, status
    assert_nil headers["set-cookie"]
  end

  test "POST /rsb/locale cookie has correct attributes" do
    env = Rack::MockRequest.env_for(
      "/rsb/locale",
      method: "POST",
      input: "locale=de&redirect_to=/admin",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded"
    )
    _status, headers, _body = @middleware.call(env)
    cookie = headers["set-cookie"]

    assert_match "path=/", cookie
    assert_match(/samesite=lax/i, cookie)
    assert_match "max-age=31536000", cookie.downcase
  end

  # --- GET /rsb/locale is NOT intercepted ---

  test "GET /rsb/locale passes through to app (not intercepted)" do
    env = Rack::MockRequest.env_for("/rsb/locale")
    status, _headers, _body = @middleware.call(env)

    assert_equal 200, status  # passes to app, not intercepted
  end

  # --- Single locale config ---

  test "middleware works with single locale (no-op)" do
    RSB::Settings.configure { |c| c.available_locales = %w[en] }
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT_LANGUAGE" => "de-DE")
    @middleware.call(env)

    assert_equal :en, @locale_during_request
  end
end
