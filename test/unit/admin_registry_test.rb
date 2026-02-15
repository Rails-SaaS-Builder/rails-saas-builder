# frozen_string_literal: true

require 'test_helper'

class AdminRegistryTest < ActiveSupport::TestCase
  test 'ResourceRegistration#route_key returns the model route_key' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Auth::Identity,
      category_name: 'Authentication',
      actions: %i[index show]
    )
    # isolate_namespace RSB::Auth strips the prefix, so we expect "identities", not "rsb_auth_identities"
    assert_equal 'identities', reg.route_key
  end

  test 'Registry#find_resource_by_route_key returns the matching registration' do
    registry = RSB::Admin::Registry.new
    registry.register_category 'Authentication' do
      resource RSB::Auth::Identity, icon: 'users', actions: %i[index show]
    end

    result = registry.find_resource_by_route_key('identities')
    assert result, 'Should find the Identity resource by route_key'
    assert_equal RSB::Auth::Identity, result.model_class
  end

  test 'Registry#find_resource_by_route_key returns nil for unknown key' do
    registry = RSB::Admin::Registry.new
    assert_nil registry.find_resource_by_route_key('nonexistent')
  end

  test 'Registry#find_page_by_key returns the matching page' do
    registry = RSB::Admin::Registry.new
    registry.register_category 'Authentication' do
      page :sessions_management,
           label: 'Active Sessions',
           icon: 'monitor',
           controller: 'rsb/auth/admin/sessions_management'
    end

    result = registry.find_page_by_key(:sessions_management)
    assert result, 'Should find the page by key'
    assert_equal 'Active Sessions', result.label
  end

  test 'Registry#find_page_by_key returns nil for unknown key' do
    registry = RSB::Admin::Registry.new
    assert_nil registry.find_page_by_key(:nonexistent)
  end
end
