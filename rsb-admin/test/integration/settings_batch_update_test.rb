# frozen_string_literal: true

require 'test_helper'

class SettingsBatchUpdateTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Settings.reset!
    RSB::Admin.reset!

    # Register a test schema with groups and depends_on
    RSB::Settings.registry.define('testcat') do
      setting :master_toggle,
              type: :boolean,
              default: true,
              group: 'Features',
              description: 'Master toggle'

      setting :sub_setting,
              type: :string,
              default: 'original',
              group: 'Features',
              depends_on: 'testcat.master_toggle',
              description: 'Sub setting'

      setting :normal_setting,
              type: :integer,
              default: 42,
              description: 'Normal setting'
    end

    RSB::Settings.registry.define('othercat') do
      setting :other_val,
              type: :string,
              default: 'hello',
              description: 'Other val'
    end

    # Create admin user with settings permissions
    role = RSB::Admin::Role.create!(
      name: "settings_admin_#{SecureRandom.hex(4)}",
      permissions: { 'settings' => %w[index update batch_update] }
    )
    @admin = RSB::Admin::AdminUser.create!(
      email: "settings-test-#{SecureRandom.hex(4)}@example.com",
      password: 'test-password-secure',
      password_confirmation: 'test-password-secure',
      role: role
    )
    sign_in_admin(@admin)
  end

  # --- Tab Navigation ---

  test 'GET /admin/settings without tab param defaults to first category' do
    get rsb_admin.settings_path
    assert_response :success
    # First category alphabetically from registry
    first_cat = RSB::Settings.registry.categories.first
    assert_match first_cat.titleize, response.body
  end

  test 'GET /admin/settings?tab=othercat shows othercat settings' do
    get rsb_admin.settings_path(tab: 'othercat')
    assert_response :success
    assert_match 'Other Val', response.body
  end

  test 'GET /admin/settings?tab=invalid falls back to first category' do
    get rsb_admin.settings_path(tab: 'nonexistent')
    assert_response :success
    first_cat = RSB::Settings.registry.categories.first
    assert_match first_cat.titleize, response.body
  end

  test 'GET /admin/settings renders tab bar with all categories' do
    get rsb_admin.settings_path
    assert_response :success
    RSB::Settings.registry.categories.each do |cat|
      assert_match cat, response.body
    end
  end

  # --- Batch Update ---

  test 'PATCH /admin/settings updates changed values and redirects with tab' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'testcat',
        tab: 'testcat',
        values: {
          master_toggle: 'true',
          sub_setting: 'changed',
          normal_setting: '99'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'testcat')
    # sub_setting changed from "original" to "changed"
    assert_equal 'changed', RSB::Settings.get('testcat.sub_setting')
    # normal_setting changed from 42 to 99
    assert_equal 99, RSB::Settings.get('testcat.normal_setting')
  end

  test 'PATCH /admin/settings skips unchanged values (no unnecessary DB writes)' do
    # Set a known value first
    RSB::Settings.set('testcat.normal_setting', 42)

    # Submit with same value — should not write to DB again
    assert_no_difference -> { RSB::Settings::Setting.count } do
      patch rsb_admin.settings_path, params: {
        settings: {
          category: 'testcat',
          tab: 'testcat',
          values: { normal_setting: '42' }
        }
      }
    end

    assert_redirected_to rsb_admin.settings_path(tab: 'testcat')
  end

  test 'PATCH /admin/settings skips locked settings' do
    RSB::Settings.configure do |config|
      config.lock('testcat.normal_setting')
    end

    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'testcat',
        tab: 'testcat',
        values: { normal_setting: '999' }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'testcat')
    # Value should NOT have changed
    assert_equal 42, RSB::Settings.get('testcat.normal_setting')
  end

  test 'PATCH /admin/settings skips depends_on disabled settings when parent is falsy' do
    # Set master_toggle to false — sub_setting should be skipped
    RSB::Settings.set('testcat.master_toggle', false)

    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'testcat',
        tab: 'testcat',
        values: {
          master_toggle: 'false',
          sub_setting: 'should_not_save'
        }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'testcat')
    # sub_setting should retain its original value, not "should_not_save"
    assert_equal 'original', RSB::Settings.get('testcat.sub_setting')
  end

  test 'PATCH /admin/settings with unknown category redirects with alert' do
    patch rsb_admin.settings_path, params: {
      settings: { category: 'bogus', tab: 'bogus', values: {} }
    }

    assert_redirected_to rsb_admin.settings_path
    assert_equal 'Unknown settings category.', flash[:alert]
  end

  test 'PATCH /admin/settings shows success flash on save' do
    patch rsb_admin.settings_path, params: {
      settings: {
        category: 'testcat',
        tab: 'testcat',
        values: { normal_setting: '100' }
      }
    }

    assert_redirected_to rsb_admin.settings_path(tab: 'testcat')
    assert_equal 'Settings updated successfully.', flash[:notice]
  end

  test 'PATCH /admin/settings requires authorization' do
    # Sign out and sign in as no-permission admin
    delete rsb_admin.logout_path

    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: 'test-password-secure',
      password_confirmation: 'test-password-secure'
    )
    sign_in_admin(no_role_admin)

    patch rsb_admin.settings_path, params: {
      settings: { category: 'testcat', tab: 'testcat', values: { normal_setting: '999' } }
    }

    # Should be denied (403 or redirect depending on admin auth pattern)
    assert_admin_denied
  end
end
