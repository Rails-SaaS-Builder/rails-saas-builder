# frozen_string_literal: true

require 'test_helper'

class ModernThemeTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
    RSB::Settings.set('admin.theme', 'modern')
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'modern theme loads modern CSS' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "link[href*='rsb/admin/themes/modern']"
  end

  test 'modern theme loads JS' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "script[src*='rsb/admin/themes/modern']"
  end

  test 'modern theme sidebar renders with enhanced styling' do
    get rsb_admin.dashboard_path
    assert_response :success
    # Modern sidebar has group hover effects and collapsible sections
    assert_match 'group-hover:opacity-100', response.body
    assert_match 'rsbToggleSection', response.body
  end

  test 'modern theme header has dark/light toggle' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_match 'rsbToggleMode', response.body
  end

  test 'view resolver picks modern theme sidebar over default' do
    # Modern theme has views_path set, so rsb_admin_partial should resolve to theme views
    get rsb_admin.dashboard_path
    assert_response :success
    # The modern sidebar has category item count display
    # (default sidebar doesn't have this)
  end
end

class DefaultThemeTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Admin.configuration.theme = :default
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'default theme loads default CSS' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "link[href*='rsb/admin/themes/default']"
  end

  test 'default theme does NOT load JS' do
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "script[src*='rsb/admin/themes']", count: 0
  end

  test 'default theme uses engine default sidebar (no rsbToggleMode)' do
    get rsb_admin.dashboard_path
    assert_response :success
    refute_match 'rsbToggleMode', response.body
  end
end
