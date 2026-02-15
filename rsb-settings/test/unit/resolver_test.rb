# frozen_string_literal: true

require 'test_helper'

module RSB
  module Settings
    class ResolverTest < ActiveSupport::TestCase
      setup do
        RSB::Settings.registry.define('test') do
          setting :mode, type: :string, default: 'default_value'
          setting :count, type: :integer, default: 10
          setting :enabled, type: :boolean, default: true
        end
      end

      test 'resolves from default when nothing else is set' do
        assert_equal 'default_value', RSB::Settings.get('test.mode')
        assert_equal 10, RSB::Settings.get('test.count')
        assert_equal true, RSB::Settings.get('test.enabled')
      end

      test 'ENV overrides default' do
        ENV['RSB_TEST_MODE'] = 'from_env'
        # Reset to clear cached resolver
        RSB::Settings.reset!
        RSB::Settings.registry.define('test') { setting :mode, type: :string, default: 'default_value' }

        assert_equal 'from_env', RSB::Settings.get('test.mode')
      ensure
        ENV.delete('RSB_TEST_MODE')
      end

      test 'initializer overrides ENV and default' do
        ENV['RSB_TEST_MODE'] = 'from_env'
        RSB::Settings.reset!
        RSB::Settings.registry.define('test') { setting :mode, type: :string, default: 'default_value' }
        RSB::Settings.configuration.set('test.mode', 'from_init')

        # Reset resolver to pick up the new configuration
        RSB::Settings.send(:instance_variable_set, :@resolver, nil)

        assert_equal 'from_init', RSB::Settings.get('test.mode')
      ensure
        ENV.delete('RSB_TEST_MODE')
      end

      test 'DB overrides everything' do
        RSB::Settings.configuration.set('test.mode', 'from_init')
        RSB::Settings::Setting.set('test', 'mode', 'from_db')

        # Reset resolver to pick up the new configuration
        RSB::Settings.send(:instance_variable_set, :@resolver, nil)

        assert_equal 'from_db', RSB::Settings.get('test.mode')
      end

      test 'type casting: integer from ENV' do
        ENV['RSB_TEST_COUNT'] = '42'
        RSB::Settings.reset!
        RSB::Settings.registry.define('test') { setting :count, type: :integer, default: 10 }

        assert_equal 42, RSB::Settings.get('test.count')
      ensure
        ENV.delete('RSB_TEST_COUNT')
      end

      test 'type casting: boolean from ENV' do
        ENV['RSB_TEST_ENABLED'] = 'false'
        RSB::Settings.reset!
        RSB::Settings.registry.define('test') { setting :enabled, type: :boolean, default: true }

        assert_equal false, RSB::Settings.get('test.enabled')
      ensure
        ENV.delete('RSB_TEST_ENABLED')
      end

      test 'type casting: integer from DB' do
        RSB::Settings::Setting.set('test', 'count', '99')

        # Reset resolver to clear cache
        RSB::Settings.send(:instance_variable_set, :@resolver, nil)

        assert_equal 99, RSB::Settings.get('test.count')
      end

      test 'set persists to DB and fires callback' do
        fired = false
        RSB::Settings.registry.on_change('test.mode') { |_old, _new| fired = true }

        RSB::Settings.set('test.mode', 'new_value')

        assert_equal 'new_value', RSB::Settings::Setting.get('test', 'mode')
        assert fired, 'Change callback should have fired'
      end

      test 'for returns all settings in a category' do
        result = RSB::Settings.for('test')
        assert_equal({ mode: 'default_value', count: 10, enabled: true }, result)
      end

      test 'for returns empty hash for unknown category' do
        result = RSB::Settings.for('nonexistent')
        assert_equal({}, result)
      end

      test 'raises on invalid key format' do
        assert_raises(ArgumentError) { RSB::Settings.get('no_dot') }
      end

      test 'cache returns same value on repeated calls' do
        first = RSB::Settings.get('test.mode')
        second = RSB::Settings.get('test.mode')
        assert_equal first, second
      end

      test 'type casting: array from ENV' do
        ENV['RSB_TEST_ITEMS'] = 'a, b, c'
        RSB::Settings.reset!
        RSB::Settings.registry.define('test') { setting :items, type: :array, default: [] }

        assert_equal %w[a b c], RSB::Settings.get('test.items')
      ensure
        ENV.delete('RSB_TEST_ITEMS')
      end

      test 'returns nil default when no schema exists for key' do
        RSB::Settings.registry.define('misc') { setting :unknown, type: :string }

        assert_nil RSB::Settings.get('misc.unknown')
      end
    end
  end
end
