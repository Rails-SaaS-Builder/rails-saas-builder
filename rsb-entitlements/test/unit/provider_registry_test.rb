require "test_helper"

module RSB
  module Entitlements
    class ProviderRegistryTest < ActiveSupport::TestCase
      setup do
        @registry = ProviderRegistry.new

        @provider_class = Class.new(PaymentProvider::Base) do
          def self.provider_key = :test
          def self.provider_label = "Test Provider"
          def self.manual_resolution? = false
          def self.admin_actions = []
          def self.refundable? = false

          def initiate! = { status: :completed }
          def complete!(_params = {}) = nil
          def reject!(_params = {}) = nil
        end
      end

      # -- register --

      test "register accepts a class inheriting from Base and returns definition" do
        definition = @registry.register(@provider_class)
        assert_instance_of ProviderDefinition, definition
        assert_equal :test, definition.key
      end

      test "register raises ArgumentError for class not inheriting Base" do
        error = assert_raises(ArgumentError) { @registry.register(String) }
        assert_match(/must inherit from/, error.message)
      end

      test "register raises ArgumentError for duplicate key" do
        @registry.register(@provider_class)
        duplicate = Class.new(PaymentProvider::Base) do
          def self.provider_key = :test
          def self.provider_label = "Duplicate"
          def initiate! = {}
          def complete!(_params = {}) = nil
          def reject!(_params = {}) = nil
        end
        assert_raises(ArgumentError) { @registry.register(duplicate) }
      end

      test "register raises ArgumentError when required_settings are missing" do
        provider_with_required = Class.new(PaymentProvider::Base) do
          def self.provider_key = :needs_config
          def self.provider_label = "Needs Config"
          def self.required_settings = [:api_key]

          settings_schema do
            setting :api_key, type: :string, default: ""
          end

          def initiate! = {}
          def complete!(_params = {}) = nil
          def reject!(_params = {}) = nil
        end

        error = assert_raises(ArgumentError) { @registry.register(provider_with_required) }
        assert_match(/required settings/, error.message)
      end

      # -- find --

      test "find returns definition by key" do
        @registry.register(@provider_class)
        definition = @registry.find(:test)
        assert_equal :test, definition.key
      end

      test "find returns nil for unknown key" do
        assert_nil @registry.find(:unknown)
      end

      test "find coerces string keys to symbols" do
        @registry.register(@provider_class)
        assert_equal :test, @registry.find("test").key
      end

      # -- all --

      test "all returns all registered definitions" do
        @registry.register(@provider_class)
        assert_equal 1, @registry.all.size
        assert_instance_of ProviderDefinition, @registry.all.first
      end

      test "all returns empty array when no providers registered" do
        assert_equal [], @registry.all
      end

      # -- keys --

      test "keys returns all registered keys as symbols" do
        @registry.register(@provider_class)
        assert_equal [:test], @registry.keys
      end

      # -- enabled --

      test "enabled returns providers where setting is true" do
        @registry.register(@provider_class)
        with_settings("entitlements.providers.test.enabled" => true) do
          assert_equal 1, @registry.enabled.size
        end
      end

      test "enabled excludes providers where setting is false" do
        @registry.register(@provider_class)
        with_settings("entitlements.providers.test.enabled" => false) do
          assert_equal 0, @registry.enabled.size
        end
      end

      # -- for_select --

      test "for_select returns array of [label, key] pairs for enabled providers" do
        @registry.register(@provider_class)
        with_settings("entitlements.providers.test.enabled" => true) do
          result = @registry.for_select
          assert_equal [["Test Provider", "test"]], result
        end
      end
    end
  end
end
