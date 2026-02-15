# frozen_string_literal: true

require 'test_helper'

class ThemeHelperTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'rsb_admin_partial returns engine default when no overrides' do
    RSB::Admin.configuration.theme = :default
    RSB::Admin.configuration.view_overrides_path = nil
    get rsb_admin.dashboard_path
    assert_response :success
    # Default theme has no views_path, so engine default partials are used
  end

  test 'layout is configurable' do
    assert_equal 'rsb/admin/application', RSB::Admin.configuration.layout
  end
end

class FormattingHelperTest < ActionView::TestCase
  include RSB::Admin::FormattingHelper

  test 'rsb_admin_badge renders span with variant class' do
    html = rsb_admin_badge('Active', variant: :success)
    assert_includes html, 'Active'
    assert_includes html, 'bg-rsb-success-bg'
  end

  test 'rsb_admin_format_value with nil returns dash' do
    html = rsb_admin_format_value(nil, nil)
    assert_includes html, '-'
  end

  test 'rsb_admin_format_value with badge formatter' do
    html = rsb_admin_format_value('active', :badge)
    assert_includes html, 'Active'
    assert_includes html, 'bg-rsb-success-bg'
  end

  test 'rsb_admin_format_value with badge auto-detects variant' do
    assert_includes rsb_admin_format_value('active', :badge), 'success'
    assert_includes rsb_admin_format_value('suspended', :badge), 'warning'
    assert_includes rsb_admin_format_value('deactivated', :badge), 'danger'
    assert_includes rsb_admin_format_value('unknown_status', :badge), 'info'
  end

  test 'rsb_admin_format_value with datetime formatter' do
    time = Time.new(2024, 6, 15, 14, 30, 0)
    result = rsb_admin_format_value(time, :datetime)
    assert_includes result, 'June 15, 2024'
    assert_includes result, '02:30 PM'
  end

  test 'rsb_admin_format_value with truncate formatter' do
    long_text = 'a' * 100
    result = rsb_admin_format_value(long_text, :truncate)
    assert result.length < 100
  end

  test 'rsb_admin_format_value with json formatter' do
    result = rsb_admin_format_value({ foo: 'bar' }, :json)
    assert_includes result, 'foo'
    assert_includes result, 'bar'
  end

  test 'rsb_admin_format_value with json formatter and empty hash' do
    result = rsb_admin_format_value({}, :json)
    assert_includes result, 'Empty'
  end

  test 'rsb_admin_format_value with proc formatter' do
    formatter = ->(val) { "formatted: #{val}" }
    result = rsb_admin_format_value('test', formatter)
    assert_equal 'formatted: test', result
  end

  test 'rsb_admin_format_value with proc formatter receiving record' do
    formatter = ->(val, rec) { "#{val} on #{rec}" }
    result = rsb_admin_format_value('test', formatter, 'record')
    assert_equal 'test on record', result
  end

  test 'rsb_admin_format_value with nil formatter and plain value' do
    result = rsb_admin_format_value('hello', nil)
    assert_equal 'hello', result
  end

  test 'rsb_admin_format_value with nil formatter and time value' do
    time = Time.new(2024, 1, 1, 12, 0, 0)
    result = rsb_admin_format_value(time, nil)
    assert_includes result, 'January 01, 2024'
  end

  test 'rsb_admin_format_value escapes HTML in plain values' do
    result = rsb_admin_format_value("<script>alert('xss')</script>", nil)
    refute_includes result, '<script>'
    assert_includes result, '&lt;script&gt;'
  end
end
