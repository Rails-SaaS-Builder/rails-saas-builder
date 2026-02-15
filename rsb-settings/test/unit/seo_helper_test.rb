require "test_helper"
require "ostruct"
require "action_view"
require "action_view/test_case"

class SeoHelperTest < ActionView::TestCase
  include RSB::Settings::SeoHelper

  setup do
    RSB::Settings.reset!
    @seo_schema = RSB::Settings::SeoSettingsSchema.build
    RSB::Settings.registry.register(@seo_schema)
  end

  teardown do
    RSB::Settings.reset!
  end

  # --- rsb_seo_title ---

  test "rsb_seo_title with page_title and app_name" do
    RSB::Settings.set("seo.app_name", "My SaaS")
    @rsb_page_title = "Sign In"
    result = rsb_seo_title
    assert_includes result, "<title>"
    assert_includes result, "Sign In | My SaaS"
    assert_includes result, "</title>"
  end

  test "rsb_seo_title with blank app_name renders just page_title" do
    RSB::Settings.set("seo.app_name", "")
    @rsb_page_title = "Sign In"
    result = rsb_seo_title
    assert_includes result, "<title>Sign In</title>"
  end

  test "rsb_seo_title with custom format" do
    RSB::Settings.set("seo.app_name", "Acme")
    RSB::Settings.set("seo.title_format", "%{page_title} — %{app_name}")
    @rsb_page_title = "Login"
    result = rsb_seo_title
    assert_includes result, "Login — Acme"
  end

  test "rsb_seo_title with no page_title and no app_name" do
    @rsb_page_title = nil
    result = rsb_seo_title
    assert_includes result, "<title></title>"
  end

  test "rsb_seo_title with app_name but no page_title renders just app_name" do
    RSB::Settings.set("seo.app_name", "Acme")
    @rsb_page_title = ""
    result = rsb_seo_title
    assert_includes result, "<title>"
    assert_includes result, "</title>"
  end

  # --- rsb_seo_meta_tags (auth context) ---

  test "rsb_seo_meta_tags renders description when present" do
    @rsb_page_title = "Sign In"
    @rsb_meta_description = "Sign in to your account"
    @rsb_seo_context = :auth
    result = rsb_seo_meta_tags
    assert_includes result, '<meta name="description" content="Sign in to your account"'
  end

  test "rsb_seo_meta_tags omits description when blank" do
    @rsb_page_title = "Sign In"
    @rsb_meta_description = nil
    @rsb_seo_context = :auth
    result = rsb_seo_meta_tags
    refute_includes result, 'name="description"'
  end

  test "rsb_seo_meta_tags renders OG tags for auth" do
    RSB::Settings.set("seo.og_image_url", "https://example.com/og.png")
    @rsb_page_title = "Sign In"
    @rsb_meta_description = "Sign in"
    @rsb_seo_context = :auth

    # Stub request
    request_stub = OpenStruct.new(original_url: "https://example.com/auth/session/new?foo=bar")
    self.define_singleton_method(:request) { request_stub }

    result = rsb_seo_meta_tags
    assert_includes result, 'property="og:title" content="Sign In"'
    assert_includes result, 'property="og:description" content="Sign in"'
    assert_includes result, 'property="og:type" content="website"'
    assert_includes result, 'property="og:url" content="https://example.com/auth/session/new"'
    assert_includes result, 'property="og:image" content="https://example.com/og.png"'
  end

  test "rsb_seo_meta_tags omits og:image when blank" do
    @rsb_page_title = "Sign In"
    @rsb_seo_context = :auth
    request_stub = OpenStruct.new(original_url: "https://example.com/auth/session/new")
    self.define_singleton_method(:request) { request_stub }

    result = rsb_seo_meta_tags
    refute_includes result, "og:image"
  end

  # --- rsb_seo_meta_tags (admin context) ---

  test "rsb_seo_meta_tags renders noindex for admin" do
    @rsb_page_title = "Dashboard"
    @rsb_seo_context = :admin
    result = rsb_seo_meta_tags
    assert_includes result, '<meta name="robots" content="noindex, nofollow"'
  end

  test "rsb_seo_meta_tags omits OG tags for admin" do
    @rsb_page_title = "Dashboard"
    @rsb_seo_context = :admin
    result = rsb_seo_meta_tags
    refute_includes result, "og:title"
    refute_includes result, "og:description"
  end

  test "rsb_seo_meta_tags omits description for admin" do
    @rsb_page_title = "Dashboard"
    @rsb_meta_description = "Some description"
    @rsb_seo_context = :admin
    result = rsb_seo_meta_tags
    refute_includes result, 'name="description"'
  end

  # --- robots for auth ---

  test "auth pages are indexable by default" do
    @rsb_page_title = "Sign In"
    @rsb_seo_context = :auth
    result = rsb_seo_meta_tags
    refute_includes result, "noindex"
  end

  test "auth pages get noindex when seo.auth_indexable is false" do
    RSB::Settings.set("seo.auth_indexable", false)
    @rsb_page_title = "Sign In"
    @rsb_seo_context = :auth
    result = rsb_seo_meta_tags
    assert_includes result, '<meta name="robots" content="noindex, nofollow"'
  end

  # --- canonical URL ---

  test "auth pages render canonical URL" do
    @rsb_page_title = "Sign In"
    @rsb_seo_context = :auth
    request_stub = OpenStruct.new(original_url: "https://example.com/auth/session/new?redirect=/foo")
    self.define_singleton_method(:request) { request_stub }

    result = rsb_seo_meta_tags
    assert_includes result, '<link rel="canonical" href="https://example.com/auth/session/new"'
  end

  test "admin pages do not render canonical URL" do
    @rsb_page_title = "Dashboard"
    @rsb_seo_context = :admin
    result = rsb_seo_meta_tags
    refute_includes result, "canonical"
  end

  # --- script injection ---

  test "rsb_seo_head_tags renders seo.head_tags setting" do
    RSB::Settings.set("seo.head_tags", '<script>console.log("head")</script>')
    result = rsb_seo_head_tags
    assert_includes result, '<script>console.log("head")</script>'
  end

  test "rsb_seo_body_tags renders seo.body_tags setting" do
    RSB::Settings.set("seo.body_tags", '<script>console.log("body")</script>')
    result = rsb_seo_body_tags
    assert_includes result, '<script>console.log("body")</script>'
  end

  test "rsb_seo_head_tags returns empty string when blank" do
    result = rsb_seo_head_tags
    assert_equal "", result
  end
end
