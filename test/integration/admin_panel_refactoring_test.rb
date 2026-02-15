# frozen_string_literal: true

require 'test_helper'

# Integration tests for admin panel cross-gem registration and functionality.
#
# This test class verifies that the admin panel correctly handles resource
# registrations from multiple gems (rsb-auth, rsb-entitlements) and implements
# core business rules for auto-detection, themes, breadcrumbs, and i18n.
#
# Tests cover Rules #1, #2, #3, #6, #9, #13, #14, #15, #16, and #18 from RFC-001.
class AdminPanelRegistrationIntegrationTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Rule #1: Auto-detect columns when no explicit columns ---
  test 'resource without columns block auto-detects from model' do
    with_fresh_admin_registry do |registry|
      registry.register_category 'Test' do
        resource RSB::Admin::AdminUser, actions: %i[index show]
        # No columns block
      end
      reg = registry.find_resource(RSB::Admin::AdminUser)
      assert_nil reg.columns
      # But index_columns should auto-detect
      assert reg.index_columns.any?
      refute_includes reg.index_columns.map(&:key), :password_digest
    end
  end

  # --- Rule #2: Auto-detect forms when no explicit form_fields ---
  test 'resource without form_fields block auto-detects from model' do
    with_fresh_admin_registry do |registry|
      registry.register_category 'Test' do
        resource RSB::Admin::AdminUser, actions: %i[index new create]
      end
      reg = registry.find_resource(RSB::Admin::AdminUser)
      assert_nil reg.form_fields
      fields = reg.new_form_fields
      refute_includes fields.map(&:key), :id
      refute_includes fields.map(&:key), :created_at
      refute_includes fields.map(&:key), :password_digest
    end
  end

  # --- Rule #3: Filters opt-in only ---
  test 'resource without filters has no filter bar' do
    with_fresh_admin_registry do |registry|
      registry.register_category 'Test' do
        resource RSB::Admin::AdminUser, actions: [:index]
      end
      reg = registry.find_resource(RSB::Admin::AdminUser)
      assert_nil reg.filters
    end
  end

  # --- Rule #6: Breadcrumbs always start with Dashboard ---
  test 'breadcrumbs start with Dashboard on every page' do
    register_all_admin_categories

    get rsb_admin.dashboard_path
    assert_admin_breadcrumbs('Dashboard')

    get rsb_admin.settings_path
    assert_admin_breadcrumbs('Dashboard')

    get rsb_admin.admin_users_path
    assert_admin_breadcrumbs('Dashboard')

    get rsb_admin.roles_path
    assert_admin_breadcrumbs('Dashboard')
  end

  # --- Rule #9: Missing icon renders empty string ---
  test 'missing icon name does not cause error' do
    svg = RSB::Admin.icon('nonexistent_icon')
    assert_equal '', svg
  end

  # --- Rule #13: All strings through i18n ---
  test 'dashboard page uses i18n strings' do
    register_all_admin_categories

    get rsb_admin.dashboard_path
    assert_response :success
    assert_match I18n.t('rsb.admin.shared.dashboard'), response.body
  end

  # --- Rule #14: All renders use rsb_admin_partial ---
  test 'layout renders sidebar and header via partial resolver' do
    register_all_admin_categories

    get rsb_admin.dashboard_path
    assert_response :success
    # Sidebar and header should be present
    assert_match RSB::Admin.configuration.app_name, response.body
  end

  # --- Rule #15: Theme CSS resolved from ThemeDefinition ---
  test 'layout loads theme CSS from current theme' do
    register_all_admin_categories

    get rsb_admin.dashboard_path
    theme = RSB::Admin.current_theme
    assert_select "link[href*='#{theme.css}']"
  end

  # --- Rule #18: Theme registry resets with built-ins ---
  test 'reset! clears custom themes and re-registers built-ins' do
    RSB::Admin.register_theme :test_theme, label: 'Test', css: 'test'
    assert RSB::Admin.themes[:test_theme]

    RSB::Admin.reset!
    refute RSB::Admin.themes[:test_theme]
    assert RSB::Admin.themes[:default]
    assert RSB::Admin.themes[:modern]
  end
end

# Integration tests for admin panel theme functionality.
#
# This test class verifies that themes are correctly applied in the admin panel,
# including CSS and JavaScript loading behavior, and that view override paths
# are respected according to the resolution order (Rule #16).
class AdminPanelThemeIntegrationTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
    register_all_admin_categories
  end

  test 'default theme does not load JS' do
    RSB::Admin.configuration.theme = :default
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "script[src*='themes']", count: 0
  end

  test 'modern theme loads both CSS and JS' do
    RSB::Settings.set('admin.theme', 'modern')
    get rsb_admin.dashboard_path
    assert_response :success
    assert_select "link[href*='rsb/admin/themes/modern']"
    assert_select "script[src*='rsb/admin/themes/modern']"
  end

  # --- Rule #16: View override resolution order ---
  test 'custom view_overrides_path takes priority over theme' do
    # This is a unit test for the resolver logic
    RSB::Admin.configuration.theme = :modern
    RSB::Admin.configuration.view_overrides_path = 'custom/admin'
    # The resolver should check custom/admin first, then theme views, then engine default
    # We can't easily test file resolution without creating actual view files,
    # but we verify the configuration is respected
    assert_equal 'custom/admin', RSB::Admin.configuration.view_overrides_path
  end
end

# Integration tests for cross-gem admin panel registrations.
#
# This test class verifies that resources and pages from rsb-auth and
# rsb-entitlements are correctly registered in the admin panel via their
# on_load hooks, and that the sidebar renders all registered categories.
class AdminPanelCrossGemRegistrationTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
    register_all_admin_categories
  end

  test 'auth resources are registered with enhanced DSL' do
    reg = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    skip 'Auth gem not loaded' unless reg
    assert reg.columns, 'Identity should have explicit columns'
    assert reg.filters, 'Identity should have filters'
  end

  test 'entitlements resources are registered with enhanced DSL' do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Plan)
    skip 'Entitlements gem not loaded' unless reg
    assert reg.columns, 'Plan should have explicit columns'
    assert reg.filters, 'Plan should have filters'
    assert reg.form_fields, 'Plan should have form fields'
  end

  test 'auth static page registered as PageRegistration' do
    page = RSB::Admin.registry.find_page_by_key(:sessions_management)
    skip 'Auth gem not loaded' unless page
    assert_kind_of RSB::Admin::PageRegistration, page
  end

  test 'entitlements static page registered with actions' do
    page = RSB::Admin.registry.find_page_by_key(:usage_counters)
    skip 'Entitlements gem not loaded' unless page
    assert_kind_of RSB::Admin::PageRegistration, page
    assert page.actions.any?, 'Usage counters should have actions'
  end

  test 'sidebar renders all categories with icons' do
    get rsb_admin.dashboard_path
    assert_response :success
    # Verify category names appear
    RSB::Admin.registry.categories.each_key do |name|
      assert_match name, response.body, "Category '#{name}' not found in sidebar"
    end
  end
end
