# frozen_string_literal: true

require 'test_helper'

class OnLoadHookTest < ActiveSupport::TestCase
  test 'on_load hooks fire when triggered' do
    registry = RSB::Admin::Registry.new
    hook_fired = false

    ActiveSupport.on_load(:rsb_admin_test_hook) do |reg|
      hook_fired = true
      reg.register_category 'TestHookCategory' do
        page :test_page, label: 'Test Page', icon: 'test', controller: 'test'
      end
    end

    ActiveSupport.run_load_hooks(:rsb_admin_test_hook, registry)

    assert hook_fired, 'on_load hook should have fired'
    assert registry.category?('TestHookCategory'), 'Category should be registered'
    assert_equal 1, registry.categories['TestHookCategory'].pages.size
  end

  test 'multiple on_load hooks fire and categories appear in registry' do
    registry = RSB::Admin::Registry.new

    ActiveSupport.on_load(:rsb_admin_multi_test) do |reg|
      reg.register_category 'Auth' do
        resource RSB::Admin::AdminUser, icon: 'users', actions: %i[index show]
      end
    end

    ActiveSupport.on_load(:rsb_admin_multi_test) do |reg|
      reg.register_category 'Billing' do
        resource RSB::Admin::Role, icon: 'credit-card', actions: [:index]
      end
    end

    ActiveSupport.run_load_hooks(:rsb_admin_multi_test, registry)

    assert registry.category?('Auth')
    assert registry.category?('Billing')
    assert_equal 2, registry.all_resources.size
  end

  test 'hooks do not fire if run_load_hooks is not called' do
    hook_fired = false

    ActiveSupport.on_load(:rsb_admin_never_fired) do |_reg|
      hook_fired = true
    end

    # Do NOT run the hooks
    refute hook_fired, 'on_load hook should not fire unless run_load_hooks is called'
  end
end
