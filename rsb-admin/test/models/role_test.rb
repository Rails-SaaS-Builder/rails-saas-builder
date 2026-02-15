# frozen_string_literal: true

require 'test_helper'

class RoleTest < ActiveSupport::TestCase
  test 'valid role' do
    role = RSB::Admin::Role.new(name: 'Editor', permissions: { 'articles' => %w[index show] })
    assert role.valid?
  end

  test 'requires name' do
    role = RSB::Admin::Role.new(permissions: { '*' => ['*'] })
    refute role.valid?
    assert_includes role.errors[:name], "can't be blank"
  end

  test 'requires unique name' do
    RSB::Admin::Role.create!(name: 'Admin', permissions: { '*' => ['*'] })
    role = RSB::Admin::Role.new(name: 'Admin', permissions: { '*' => ['*'] })
    refute role.valid?
    assert_includes role.errors[:name], 'has already been taken'
  end

  test 'allows empty permissions' do
    # Permissions column has a default of {}, so empty permissions are valid
    # (role with no access to anything)
    role = RSB::Admin::Role.new(name: 'Empty')
    assert role.valid?
    assert_equal({}, role.permissions)
  end

  test 'can? with specific permissions' do
    role = RSB::Admin::Role.create!(name: 'Editor', permissions: {
                                      'articles' => %w[index show edit update],
                                      'categories' => ['index']
                                    })

    assert role.can?('articles', 'index')
    assert role.can?('articles', 'edit')
    refute role.can?('articles', 'destroy')
    assert role.can?('categories', 'index')
    refute role.can?('categories', 'edit')
    refute role.can?('settings', 'index')
  end

  test 'can? with wildcard resource actions' do
    role = RSB::Admin::Role.create!(name: 'ArticleAdmin', permissions: {
                                      'articles' => ['*']
                                    })

    assert role.can?('articles', 'index')
    assert role.can?('articles', 'destroy')
    refute role.can?('settings', 'index')
  end

  test 'can? with superadmin wildcard' do
    role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })

    assert role.can?('articles', 'index')
    assert role.can?('settings', 'update')
    assert role.can?('anything', 'any_action')
  end

  test 'superadmin? returns true for wildcard permissions' do
    role = RSB::Admin::Role.new(name: 'Super', permissions: { '*' => ['*'] })
    assert role.superadmin?
  end

  test 'superadmin? returns false for limited permissions' do
    role = RSB::Admin::Role.new(name: 'Editor', permissions: { 'articles' => ['index'] })
    refute role.superadmin?
  end

  test 'superadmin? returns false for empty permissions' do
    role = RSB::Admin::Role.new(name: 'None', permissions: {})
    refute role.superadmin?
  end

  test 'permissions_json= parses valid JSON' do
    role = RSB::Admin::Role.new(name: 'Test')
    role.permissions_json = '{"articles": ["index", "show"]}'
    assert_equal({ 'articles' => %w[index show] }, role.permissions)
  end

  test 'permissions_json= adds error for invalid JSON' do
    role = RSB::Admin::Role.new(name: 'Test')
    role.permissions_json = 'not json'
    assert role.errors[:permissions].any?
  end
end
