# frozen_string_literal: true

require 'test_helper'

class I18nLocaleTest < ActiveSupport::TestCase
  test 'en.yml is loaded and accessible' do
    assert_equal 'Dashboard', I18n.t('rsb.admin.shared.dashboard')
    assert_equal 'Sign in', I18n.t('rsb.admin.sessions.sign_in')
    assert_equal 'Settings', I18n.t('rsb.admin.settings.title')
  end

  test 'interpolation works' do
    assert_equal 'New User', I18n.t('rsb.admin.shared.new', resource: 'User')
    assert_equal 'No Users found', I18n.t('rsb.admin.shared.no_results', resource: 'Users')
    assert_equal 'Showing 1-25 of 100', I18n.t('rsb.admin.shared.showing', from: 1, to: 25, total: 100)
  end

  test 'column global labels are accessible' do
    assert_equal 'ID', I18n.t('rsb.admin.columns.id')
    assert_equal 'Email', I18n.t('rsb.admin.columns.email')
    assert_equal 'Status', I18n.t('rsb.admin.columns.status')
  end

  test 'breadcrumb_home key does not exist' do
    assert_nil I18n.t('rsb.admin.shared.breadcrumb_home', default: nil)
  end
end

class I18nHelperTest < ActionDispatch::IntegrationTest
  include RSB::Admin::I18nHelper

  test 'rsb_admin_t delegates to i18n with prefix' do
    assert_equal 'Dashboard', rsb_admin_t('shared.dashboard')
    assert_equal 'Sign in', rsb_admin_t('sessions.sign_in')
  end

  test 'rsb_admin_column_label falls back to DSL label' do
    col = RSB::Admin::ColumnDefinition.build(:custom_field, label: 'My Field')
    assert_equal 'My Field', rsb_admin_column_label(col)
  end

  test 'rsb_admin_column_label uses global i18n when available' do
    col = RSB::Admin::ColumnDefinition.build(:email, label: 'Fallback')
    # Global i18n key exists: rsb.admin.columns.email = "Email"
    assert_equal 'Email', rsb_admin_column_label(col)
  end

  test 'rsb_admin_column_label uses per-resource i18n when available' do
    # Add per-resource override
    I18n.backend.store_translations(:en, {
                                      rsb: { admin: { resources: { identities: { columns: { email: 'Identity Email' } } } } }
                                    })

    col = RSB::Admin::ColumnDefinition.build(:email, label: 'Fallback')
    assert_equal 'Identity Email', rsb_admin_column_label(col, resource_key: 'identities')
  ensure
    I18n.reload!
  end

  test 'rsb_admin_filter_label falls back to filter label' do
    filter = RSB::Admin::FilterDefinition.build(:custom, label: 'Custom Filter')
    assert_equal 'Custom Filter', rsb_admin_filter_label(filter)
  end

  test 'rsb_admin_field_label falls back to field label' do
    field = RSB::Admin::FormFieldDefinition.build(:custom, label: 'Custom Field')
    assert_equal 'Custom Field', rsb_admin_field_label(field)
  end
end
