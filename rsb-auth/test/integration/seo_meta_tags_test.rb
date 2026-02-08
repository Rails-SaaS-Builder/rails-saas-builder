require "test_helper"

class SeoMetaTagsTest < ActionDispatch::IntegrationTest
  setup do
    register_auth_settings
    register_auth_credentials
    # Register SEO settings
    RSB::Settings.registry.register(RSB::Settings::SeoSettingsSchema.build)
  end

  test "login page has dynamic title" do
    RSB::Settings.set("seo.app_name", "TestApp")
    get "/auth/session/new"
    assert_response :success
    assert_select "title", text: /Sign In.*TestApp/
  end

  test "login page has meta description" do
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[name="description"]'
  end

  test "login page has OG tags" do
    RSB::Settings.set("seo.og_image_url", "https://example.com/og.png")
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[property="og:title"]'
    assert_select 'meta[property="og:type"][content="website"]'
    assert_select 'meta[property="og:image"][content="https://example.com/og.png"]'
  end

  test "login page has canonical URL" do
    get "/auth/session/new"
    assert_response :success
    assert_select 'link[rel="canonical"]'
  end

  test "login page has no noindex by default" do
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0
  end

  test "login page has noindex when auth_indexable is false" do
    RSB::Settings.set("seo.auth_indexable", false)
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  test "registration page has page title" do
    get "/auth/registration/new"
    assert_response :success
    assert_select "title", text: /Create Account|Sign Up/
  end

  test "password reset page has page title" do
    get "/auth/password_resets/new"
    assert_response :success
    assert_select "title", text: /Reset|Password/i
  end

  test "head_tags setting is rendered in layout" do
    RSB::Settings.set("seo.head_tags", "<!-- test-head-tag -->")
    get "/auth/session/new"
    assert_response :success
    assert_includes response.body, "<!-- test-head-tag -->"
  end

  test "body_tags setting is rendered in layout" do
    RSB::Settings.set("seo.body_tags", "<!-- test-body-tag -->")
    get "/auth/session/new"
    assert_response :success
    assert_includes response.body, "<!-- test-body-tag -->"
  end

  test "title with no app_name has no suffix" do
    RSB::Settings.set("seo.app_name", "")
    get "/auth/session/new"
    assert_response :success
    # Title should be just the page title, no pipe separator
    assert_select "title" do |elements|
      title_text = elements.first.text
      refute_includes title_text, "|"
    end
  end
end
