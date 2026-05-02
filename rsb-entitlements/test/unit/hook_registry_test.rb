# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class HookRegistryTest < ActiveSupport::TestCase
      setup do
        RSB::Entitlements.reset!
      end

      teardown do
        RSB::Entitlements.reset!
      end

      test 'RSB::Entitlements.on(:event) registers a subscriber' do
        received = []
        RSB::Entitlements.on(:something) { |arg| received << arg }

        assert_instance_of RSB::Entitlements::HookRegistry, RSB::Entitlements.hooks

        RSB::Entitlements.hooks.fire(:something, 'x')
        assert_equal ['x'], received
      end

      test 'multiple subscribers per event fire in registration order' do
        order = []
        RSB::Entitlements.on(:ordered_event) { order << :first }
        RSB::Entitlements.on(:ordered_event) { order << :second }

        RSB::Entitlements.hooks.fire(:ordered_event)
        assert_equal %i[first second], order
      end

      test 'hooks.fire(:event, arg1, arg2) passes args through' do
        captured = nil
        RSB::Entitlements.on(:multi_arg) { |*args| captured = args }

        RSB::Entitlements.hooks.fire(:multi_arg, 1, 'two', :three)
        assert_equal [1, 'two', :three], captured
      end

      test 'subscriber raise propagates and aborts subsequent subscribers' do
        fired = []
        RSB::Entitlements.on(:kaboom) { fired << :a }
        RSB::Entitlements.on(:kaboom) { raise 'boom' }
        RSB::Entitlements.on(:kaboom) { fired << :c }

        err = assert_raises(RuntimeError) do
          RSB::Entitlements.hooks.fire(:kaboom)
        end
        assert_equal 'boom', err.message
        assert_equal [:a], fired
      end

      test 'hooks.reset! clears all subscribers' do
        mutated = false
        RSB::Entitlements.on(:clearable) { mutated = true }

        RSB::Entitlements.hooks.reset!
        RSB::Entitlements.hooks.fire(:clearable)
        assert_equal false, mutated
      end

      test 'RSB::Entitlements.reset! clears hooks' do
        mutated = false
        RSB::Entitlements.on(:module_clearable) { mutated = true }

        RSB::Entitlements.reset!
        RSB::Entitlements.hooks.fire(:module_clearable)
        assert_equal false, mutated
      end

      test 'fire on unknown event with no subscribers is a no-op' do
        assert_nothing_raised do
          RSB::Entitlements.hooks.fire(:never_registered, 'arg')
        end
      end

      test 'HookRegistry can be instantiated and used directly' do
        registry = RSB::Entitlements::HookRegistry.new
        received = []
        registry.on(:direct_event) { |x| received << x }

        registry.fire(:direct_event, 'value')
        assert_equal ['value'], received

        registry.reset!
        registry.fire(:direct_event, 'after_reset')
        assert_equal ['value'], received # no new entries after reset
      end
    end
  end
end
