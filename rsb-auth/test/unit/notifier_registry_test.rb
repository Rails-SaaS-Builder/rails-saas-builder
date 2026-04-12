# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class NotifierRegistryTest < ActiveSupport::TestCase
      setup do
        @registry = NotifierRegistry.new
      end

      test 'register adds a notifier subclass' do
        notifier = build_test_notifier(:test_channel)
        @registry.register(notifier)
        assert_equal notifier, @registry.find(:test_channel)
      end

      test 'register raises ArgumentError for non-Base subclass' do
        assert_raises(ArgumentError) do
          @registry.register(String)
        end
      end

      test 'register raises ArgumentError for Base itself' do
        assert_raises(ArgumentError) do
          @registry.register(InvitationNotifier::Base)
        end
      end

      test 'find returns nil for unregistered channel' do
        assert_nil @registry.find(:nonexistent)
      end

      test 'find accepts string keys and converts to symbol' do
        notifier = build_test_notifier(:email)
        @registry.register(notifier)
        assert_equal notifier, @registry.find('email')
      end

      test 'all returns all registered notifier classes' do
        a = build_test_notifier(:channel_a)
        b = build_test_notifier(:channel_b)
        @registry.register(a)
        @registry.register(b)

        assert_equal [a, b], @registry.all
      end

      test 'keys returns all registered channel keys' do
        @registry.register(build_test_notifier(:email))
        @registry.register(build_test_notifier(:sms))

        assert_equal %i[email sms], @registry.keys
      end

      test 'register overwrites existing notifier for same channel_key' do
        first = build_test_notifier(:email)
        second = build_test_notifier(:email)
        @registry.register(first)
        @registry.register(second)
        assert_equal second, @registry.find(:email)
        assert_equal 1, @registry.all.size
      end

      private

      def build_test_notifier(channel)
        Class.new(InvitationNotifier::Base) do
          define_singleton_method(:channel_key) { channel }
          define_singleton_method(:form_fields) { [] }
          define_method(:deliver!) { |_inv, _fields: {}| nil }
        end
      end
    end
  end
end
