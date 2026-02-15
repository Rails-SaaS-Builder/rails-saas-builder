# frozen_string_literal: true

require 'test_helper'

class CategoryRegistrationTest < ActiveSupport::TestCase
  test 'initializes with name' do
    cat = RSB::Admin::CategoryRegistration.new('Authentication')
    assert_equal 'Authentication', cat.name
    assert_equal [], cat.resources
    assert_equal [], cat.pages
  end

  test 'resource DSL adds a ResourceRegistration' do
    cat = RSB::Admin::CategoryRegistration.new('System')
    cat.resource RSB::Admin::Role, icon: 'shield', label: 'Roles', actions: %i[index show]

    assert_equal 1, cat.resources.size
    resource = cat.resources.first
    assert_equal RSB::Admin::Role, resource.model_class
    assert_equal 'System', resource.category_name
    assert_equal 'shield', resource.icon
    assert_equal 'Roles', resource.label
    assert_equal %i[index show], resource.actions
  end

  test 'resource DSL defaults label from model name' do
    cat = RSB::Admin::CategoryRegistration.new('System')
    cat.resource RSB::Admin::Role

    resource = cat.resources.first
    assert_includes resource.label, 'Role'
  end

  test 'page DSL adds a PageRegistration object' do
    cat = RSB::Admin::CategoryRegistration.new('Auth')
    cat.page :sessions_management, label: 'Active Sessions', icon: 'monitor', controller: 'rsb/auth/admin/sessions'

    assert_equal 1, cat.pages.size
    page = cat.pages.first
    assert_kind_of RSB::Admin::PageRegistration, page
    assert_equal :sessions_management, page.key
    assert_equal 'Active Sessions', page.label
    assert_equal 'monitor', page.icon
    assert_equal 'rsb/auth/admin/sessions', page.controller
    assert_equal 'Auth', page.category_name
  end

  test 'find_resource finds by model class' do
    cat = RSB::Admin::CategoryRegistration.new('System')
    cat.resource RSB::Admin::Role, actions: [:index]
    cat.resource RSB::Admin::AdminUser, actions: [:show]

    found = cat.find_resource(RSB::Admin::Role)
    assert_not_nil found
    assert_equal RSB::Admin::Role, found.model_class

    not_found = cat.find_resource(String)
    assert_nil not_found
  end

  test 'merge combines resources and pages from another category' do
    cat1 = RSB::Admin::CategoryRegistration.new('Auth')
    cat1.resource RSB::Admin::Role, actions: [:index]

    cat2 = RSB::Admin::CategoryRegistration.new('Auth')
    cat2.resource RSB::Admin::AdminUser, actions: [:show]
    cat2.page :test_page, label: 'Test', icon: 'test', controller: 'test'

    cat1.merge(cat2)

    assert_equal 2, cat1.resources.size
    assert_equal 1, cat1.pages.size
  end
end
