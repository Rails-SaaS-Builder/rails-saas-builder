# frozen_string_literal: true

require 'test_helper'

class SettingsPageTest < ActionDispatch::IntegrationTest
  setup do
    # Re-register admin settings schema (reset clears it between tests)
    RSB::Settings.registry.register(RSB::Admin.settings_schema)

    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
  end

  test 'settings page renders all categories from registry' do
    get rsb_admin.settings_path
    assert_response :success
    assert_select 'h1', 'Settings'
    # Admin settings schema should be registered via the engine
    assert_match 'Admin', response.body
  end

  test 'settings page shows admin theme setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Theme', response.body
  end

  test 'settings page shows admin per_page setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Per Page', response.body
  end

  test 'settings page shows admin app_name setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'App Name', response.body
  end

  test 'updating a setting persists and redirects' do
    patch rsb_admin.setting_path(category: 'admin', key: 'app_name'), params: { value: 'My Custom Admin' }
    assert_redirected_to rsb_admin.settings_path

    assert_equal 'My Custom Admin', RSB::Settings.get('admin.app_name')
  end

  test 'locked settings cannot be updated' do
    RSB::Settings.configure do |config|
      config.lock 'admin.theme'
    end

    patch rsb_admin.setting_path(category: 'admin', key: 'theme'), params: { value: 'dark' }
    assert_redirected_to rsb_admin.settings_path
    follow_redirect!
    assert_match 'locked', response.body.downcase
  end

  test 'locked settings are shown as read-only' do
    RSB::Settings.configure do |config|
      config.lock 'admin.theme'
    end

    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Locked', response.body
  end

  test 'settings page shows enabled setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Enabled', response.body
  end

  test 'settings page shows company_name setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Company Name', response.body
  end

  test 'settings page shows logo_url setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Logo Url', response.body
  end

  test 'settings page shows footer_text setting' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match 'Footer Text', response.body
  end

  test 'settings page renders theme enum as select from proc' do
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_select 'select' do
      assert_select 'option', text: 'Default'
      assert_select 'option', text: 'Modern'
    end
  end
end
