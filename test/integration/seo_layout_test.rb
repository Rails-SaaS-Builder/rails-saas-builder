require "test_helper"

class SeoLayoutTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Settings.reset!
    RSB::Auth.reset!
    RSB::Admin.reset!
    register_all_settings
    register_all_credentials
    register_all_admin
  end

  teardown do
    RSB::Settings.reset!
    RSB::Auth.reset!
    RSB::Admin.reset!
  end

  test "auth and admin both use seo.app_name for titles" do
    RSB::Settings.set("seo.app_name", "SharedApp")

    # Auth page
    get "/auth/session/new"
    assert_response :success
    assert_select "title", text: /SharedApp/

    # Admin page
    get "/admin/login"
    assert_response :success
    assert_select "title", text: /SharedApp/
  end

  test "auth pages have OG tags while admin does not" do
    # Auth
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[property="og:type"]'

    # Admin
    get "/admin/login"
    assert_response :success
    assert_select 'meta[property="og:type"]', count: 0
  end

  test "admin pages have noindex while auth does not by default" do
    # Auth (indexable by default)
    get "/auth/session/new"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0

    # Admin (always noindex)
    get "/admin/login"
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  test "head_tags and body_tags work on both auth and admin" do
    RSB::Settings.set("seo.head_tags", "<!-- shared-head -->")
    RSB::Settings.set("seo.body_tags", "<!-- shared-body -->")

    get "/auth/session/new"
    assert_includes response.body, "<!-- shared-head -->"
    assert_includes response.body, "<!-- shared-body -->"

    get "/admin/login"
    assert_includes response.body, "<!-- shared-head -->"
    assert_includes response.body, "<!-- shared-body -->"
  end
end
