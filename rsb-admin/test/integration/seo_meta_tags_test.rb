# frozen_string_literal: true

require 'test_helper'

class SeoMetaTagsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Settings.registry.register(RSB::Settings::SeoSettingsSchema.build)
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
  end

  teardown do
    RSB::Admin::AdminSession.delete_all
    RSB::Admin::AdminUser.delete_all
    RSB::Admin::Role.delete_all
  end

  test 'admin login page has dynamic title' do
    RSB::Settings.set('seo.app_name', 'TestApp')
    get '/admin/login'
    assert_response :success
    assert_select 'title', text: /Sign In.*TestApp|Admin.*Sign In/
  end

  test 'admin login page has noindex' do
    get '/admin/login'
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  test 'admin login page has no OG tags' do
    get '/admin/login'
    assert_response :success
    assert_select 'meta[property="og:title"]', count: 0
  end

  test 'admin login page has no meta description' do
    get '/admin/login'
    assert_response :success
    assert_select 'meta[name="description"]', count: 0
  end

  test 'admin dashboard has dynamic title' do
    RSB::Settings.set('seo.app_name', 'TestApp')
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin'
    assert_response :success
    assert_select 'title', text: /Dashboard.*TestApp/
  end

  test 'admin dashboard has noindex' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin'
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  test 'admin dashboard has no canonical URL' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin'
    assert_response :success
    assert_select 'link[rel="canonical"]', count: 0
  end

  test 'admin head_tags setting is rendered' do
    RSB::Settings.set('seo.head_tags', '<!-- admin-head-tag -->')
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin'
    assert_response :success
    assert_includes response.body, '<!-- admin-head-tag -->'
  end

  test 'admin body_tags setting is rendered' do
    RSB::Settings.set('seo.body_tags', '<!-- admin-body-tag -->')
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin'
    assert_response :success
    assert_includes response.body, '<!-- admin-body-tag -->'
  end

  test 'settings page has page title' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    get '/admin/settings'
    assert_response :success
    assert_select 'title', text: /Settings/
  end
end
