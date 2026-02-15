# frozen_string_literal: true

require 'test_helper'

class ColumnDefinitionTest < ActiveSupport::TestCase
  test 'build with defaults' do
    col = RSB::Admin::ColumnDefinition.build(:email)
    assert_equal :email, col.key
    assert_equal 'Email', col.label
    assert_equal false, col.sortable
    assert_nil col.formatter
    assert_equal false, col.link
    assert_equal %i[index show], col.visible_on
  end

  test 'build id column defaults link to true' do
    col = RSB::Admin::ColumnDefinition.build(:id)
    assert_equal true, col.link
  end

  test 'build with custom options' do
    col = RSB::Admin::ColumnDefinition.build(:status, label: 'State', sortable: true, formatter: :badge, link: false,
                                                      visible_on: [:index])
    assert_equal 'State', col.label
    assert_equal true, col.sortable
    assert_equal :badge, col.formatter
    assert_equal false, col.link
    assert_equal [:index], col.visible_on
  end

  test 'visible_on? returns true for matching context' do
    col = RSB::Admin::ColumnDefinition.build(:email, visible_on: [:index])
    assert col.visible_on?(:index)
    refute col.visible_on?(:show)
  end
end

class FilterDefinitionTest < ActiveSupport::TestCase
  test 'build with defaults' do
    filter = RSB::Admin::FilterDefinition.build(:email)
    assert_equal :email, filter.key
    assert_equal 'Email', filter.label
    assert_equal :text, filter.type
    assert_nil filter.options
    assert_nil filter.scope
  end

  test 'build with custom options' do
    filter = RSB::Admin::FilterDefinition.build(:status, type: :select, options: %w[active suspended])
    assert_equal :select, filter.type
    assert_equal %w[active suspended], filter.options
  end

  test 'apply with default text scope' do
    filter = RSB::Admin::FilterDefinition.build(:email, type: :text)
    # Create a simple mock object that captures the where call
    relation = Object.new
    def relation.where(sql, value)
      @where_called = [sql, value]
      self
    end

    def relation.where_args
      @where_called
    end

    result = filter.apply(relation, 'john')
    assert_equal ['email LIKE ?', '%john%'], relation.where_args
    assert_equal relation, result
  end

  test 'apply with blank value returns relation unchanged' do
    filter = RSB::Admin::FilterDefinition.build(:email)
    relation = Object.new
    assert_equal relation, filter.apply(relation, '')
    assert_equal relation, filter.apply(relation, nil)
  end

  test 'apply with proc scope' do
    custom_scope = ->(_rel, val) { "filtered_#{val}" }
    filter = RSB::Admin::FilterDefinition.build(:search, scope: custom_scope)
    assert_equal 'filtered_test', filter.apply(nil, 'test')
  end
end

class FormFieldDefinitionTest < ActiveSupport::TestCase
  test 'build with defaults' do
    field = RSB::Admin::FormFieldDefinition.build(:name)
    assert_equal :name, field.key
    assert_equal 'Name', field.label
    assert_equal :text, field.type
    assert_equal false, field.required
    assert_nil field.hint
    assert_equal %i[new edit], field.visible_on
  end

  test 'build with custom options' do
    field = RSB::Admin::FormFieldDefinition.build(:email, type: :email, required: true, hint: 'User email',
                                                          visible_on: [:new])
    assert_equal :email, field.type
    assert_equal true, field.required
    assert_equal 'User email', field.hint
    assert_equal [:new], field.visible_on
  end

  test 'visible_on? returns true for matching context' do
    field = RSB::Admin::FormFieldDefinition.build(:email, visible_on: [:new])
    assert field.visible_on?(:new)
    refute field.visible_on?(:edit)
  end
end

class PageRegistrationTest < ActiveSupport::TestCase
  test 'build with defaults' do
    page = RSB::Admin::PageRegistration.build(
      key: :dashboard, label: 'Dashboard', controller: 'admin/dashboard', category_name: 'System'
    )
    assert_equal :dashboard, page.key
    assert_equal 'Dashboard', page.label
    assert_nil page.icon
    assert_equal 'admin/dashboard', page.controller
    assert_equal 'System', page.category_name
    assert_equal [], page.actions
  end

  test 'build with actions normalizes keys' do
    page = RSB::Admin::PageRegistration.build(
      key: :usage, label: 'Usage', controller: 'admin/usage', category_name: 'Billing',
      actions: [{ key: :index, label: 'Overview' }, { key: :by_metric, label: 'By Metric', method: :post }]
    )
    assert_equal 2, page.actions.size
    assert_equal :index, page.actions[0][:key]
    assert_equal :get, page.actions[0][:method]
    assert_equal :post, page.actions[1][:method]
  end

  test 'from_hash wraps legacy hash' do
    hash = { key: :sessions, label: 'Sessions', icon: 'monitor', controller: 'admin/sessions', category_name: 'Auth' }
    page = RSB::Admin::PageRegistration.from_hash(hash)
    assert_equal :sessions, page.key
    assert_equal 'monitor', page.icon
    assert_equal [], page.actions
  end

  test 'action_keys returns list of action key symbols' do
    page = RSB::Admin::PageRegistration.build(
      key: :usage, label: 'Usage', controller: 'c', category_name: 'B',
      actions: [{ key: :index, label: 'Overview' }, { key: :by_metric, label: 'By Metric' }]
    )
    assert_equal %i[index by_metric], page.action_keys
  end

  test 'find_action returns matching action hash' do
    page = RSB::Admin::PageRegistration.build(
      key: :usage, label: 'Usage', controller: 'c', category_name: 'B',
      actions: [{ key: :index, label: 'Overview' }, { key: :by_metric, label: 'By Metric' }]
    )
    action = page.find_action(:by_metric)
    assert_equal :by_metric, action[:key]
    assert_equal 'By Metric', action[:label]
  end
end

class BreadcrumbItemTest < ActiveSupport::TestCase
  test 'create with label and path' do
    item = RSB::Admin::BreadcrumbItem.new(label: 'Dashboard', path: '/admin')
    assert_equal 'Dashboard', item.label
    assert_equal '/admin', item.path
  end

  test 'create with nil path for current page' do
    item = RSB::Admin::BreadcrumbItem.new(label: 'Edit', path: nil)
    assert_equal 'Edit', item.label
    assert_nil item.path
  end
end

class ThemeDefinitionTest < ActiveSupport::TestCase
  test 'create with all fields' do
    theme = RSB::Admin::ThemeDefinition.new(
      key: :modern, label: 'Modern', css: 'rsb/admin/themes/modern',
      js: 'rsb/admin/themes/modern', views_path: 'rsb/admin/themes/modern/views'
    )
    assert_equal :modern, theme.key
    assert_equal 'rsb/admin/themes/modern', theme.css
    assert_equal 'rsb/admin/themes/modern/views', theme.views_path
  end

  test 'create with minimal fields' do
    theme = RSB::Admin::ThemeDefinition.new(
      key: :default, label: 'Default', css: 'rsb/admin/themes/default', js: nil, views_path: nil
    )
    assert_nil theme.js
    assert_nil theme.views_path
  end
end
