# frozen_string_literal: true

require_relative '../../test_helper'

class AuthAdminRegistrationTest < ActiveSupport::TestCase
  setup do
    RSB::Admin.reset!
    # Simulate the on_load hook
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)
  end

  test 'Identity resource has explicit columns' do
    reg = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert reg, 'Identity not registered'
    assert reg.columns, 'Identity should have explicit columns'
    assert_equal 6, reg.columns.size, 'Identity should have 6 columns'

    column_keys = reg.columns.map(&:key)
    assert_includes column_keys, :id
    assert_includes column_keys, :status
    assert_includes column_keys, :primary_identifier
    assert_includes column_keys, :credentials_count
    assert_includes column_keys, :created_at
    assert_includes column_keys, :updated_at
  end

  test 'Identity resource has status, credential, and credential_type filters' do
    reg = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert reg.filters, 'Identity should have filters'
    assert_equal 3, reg.filters.size, 'Identity should have 3 filters'

    filter_keys = reg.filters.map(&:key)
    assert_includes filter_keys, :status
    assert_includes filter_keys, :credential
    assert_includes filter_keys, :credential_type

    status_filter = reg.filters.find { |f| f.key == :status }
    assert_equal :select, status_filter.type
    assert_equal %w[active suspended deactivated deleted], status_filter.options

    credential_filter = reg.filters.find { |f| f.key == :credential }
    assert_equal :text, credential_filter.type
    assert credential_filter.scope.is_a?(Proc), 'credential filter should have a custom scope'

    credential_type_filter = reg.filters.find { |f| f.key == :credential_type }
    assert_equal :select, credential_type_filter.type
    assert credential_type_filter.options.is_a?(Proc), 'credential_type filter options should be a Proc'
    assert credential_type_filter.scope.is_a?(Proc), 'credential_type filter should have a custom scope'
  end

  test 'Identity resource has per_page and default_sort' do
    reg = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert_equal 30, reg.per_page
    assert_equal({ column: :created_at, direction: :desc }, reg.default_sort)
  end

  test 'Invitation resource has columns, filters, and form fields' do
    reg = RSB::Admin.registry.find_resource(RSB::Auth::Invitation)
    assert reg, 'Invitation not registered'

    # Test columns
    assert reg.columns, 'Invitation should have explicit columns'
    assert_equal 7, reg.columns.size, 'Invitation should have 7 columns'

    column_keys = reg.columns.map(&:key)
    assert_includes column_keys, :id
    assert_includes column_keys, :email
    assert_includes column_keys, :token
    assert_includes column_keys, :status
    assert_includes column_keys, :invited_by_type
    assert_includes column_keys, :expires_at
    assert_includes column_keys, :accepted_at

    # Test filters
    assert reg.filters, 'Invitation should have filters'
    assert_equal 2, reg.filters.size, 'Invitation should have 2 filters'

    filter_keys = reg.filters.map(&:key)
    assert_includes filter_keys, :email
    assert_includes filter_keys, :status

    # Test form fields
    assert reg.form_fields, 'Invitation should have form fields'
    assert_equal 1, reg.form_fields.size, 'Invitation should have 1 form field'

    email_field = reg.form_fields.first
    assert_equal :email, email_field.key
    assert_equal :email, email_field.type
    assert email_field.required, 'Email field should be required'
  end

  test 'Sessions management page has actions' do
    page = RSB::Admin.registry.find_page_by_key(:sessions_management)
    assert page, 'Sessions management page not registered'
    assert_kind_of RSB::Admin::PageRegistration, page

    assert_equal 2, page.actions.size, 'Sessions management should have 2 actions'

    index_action = page.actions.find { |a| a[:key] == :index }
    assert index_action, 'Index action not found'
    assert_equal 'Active Sessions', index_action[:label]

    destroy_action = page.actions.find { |a| a[:key] == :destroy }
    assert destroy_action, 'Destroy action not found'
    assert_equal :delete, destroy_action[:method]
  end
end
