module RSB
  module Entitlements
    # Registry for payment provider classes. Providers register by passing
    # their class (which must inherit from PaymentProvider::Base).
    # The registry validates the class, builds a ProviderDefinition,
    # and registers the provider's settings schema into RSB::Settings.
    #
    # @example
    #   RSB::Entitlements.providers.register(MyProvider)
    #   RSB::Entitlements.providers.find(:my_provider)
    #   RSB::Entitlements.providers.enabled
    class ProviderRegistry
      def initialize
        @definitions = {}
      end

      # Register a payment provider class.
      #
      # @param provider_class [Class] must inherit from PaymentProvider::Base
      # @return [ProviderDefinition]
      # @raise [ArgumentError] if class is invalid, key is duplicate, or required settings are missing
      def register(provider_class)
        unless provider_class.is_a?(Class) && provider_class < PaymentProvider::Base
          raise ArgumentError,
            "#{provider_class} must inherit from RSB::Entitlements::PaymentProvider::Base"
        end

        key = provider_class.provider_key
        raise ArgumentError, "Provider key :#{key} is already registered" if @definitions.key?(key)

        # Register provider's settings schema (if declared)
        register_provider_settings(provider_class)

        # Validate required settings have non-default values
        validate_required_settings(provider_class)

        # Build and store the definition
        definition = ProviderDefinition.build_from(provider_class)
        @definitions[key] = definition
        definition
      end

      # Find a provider definition by key.
      #
      # @param key [Symbol, String] provider key
      # @return [ProviderDefinition, nil]
      def find(key)
        @definitions[key.to_sym]
      end

      # All registered provider definitions.
      #
      # @return [Array<ProviderDefinition>]
      def all
        @definitions.values
      end

      # All registered provider keys.
      #
      # @return [Array<Symbol>]
      def keys
        @definitions.keys
      end

      # Providers where the `entitlements.providers.<key>.enabled` setting is true.
      #
      # @return [Array<ProviderDefinition>]
      def enabled
        all.select do |definition|
          RSB::Settings.get("entitlements.providers.#{definition.key}.enabled") != false
        end
      end

      # Array of [label, key] pairs for form dropdowns. Only includes enabled providers.
      #
      # @return [Array<Array(String, String)>]
      def for_select
        enabled.map { |d| [d.label, d.key.to_s] }
      end

      private

      # Register the provider's settings schema into RSB::Settings
      # under the `entitlements` category with compound keys like
      # `providers.<key>.enabled`.
      # Adds an `enabled` setting (default: true) unless the provider
      # defines its own `enabled` setting.
      def register_provider_settings(provider_class)
        key = provider_class.provider_key
        schema_block = provider_class.settings_schema
        prefix = "providers.#{key}"
        provider_label = provider_class.provider_label

        schema = RSB::Settings::Schema.new("entitlements")

        # Collect provider's custom settings first to check for enabled override
        custom_settings = []
        provider_defines_enabled = false

        if schema_block
          collector = RSB::Settings::Schema.new("_collector")
          collector.instance_eval(&schema_block)
          custom_settings = collector.definitions
          provider_defines_enabled = custom_settings.any? { |defn| defn.key == :enabled }
        end

        # Add auto-generated enabled setting only if provider doesn't define it
        unless provider_defines_enabled
          schema.setting :"#{prefix}.enabled",
                          type: :boolean,
                          default: true,
                          description: "Enable #{provider_label} provider"
        end

        # Register all provider's settings with the prefix
        custom_settings.each do |defn|
          schema.setting :"#{prefix}.#{defn.key}",
                          type: defn.type,
                          default: defn.default,
                          description: defn.description
        end

        RSB::Settings.registry.register(schema)
      end

      # Validate that all required settings have non-default values.
      def validate_required_settings(provider_class)
        return if provider_class.required_settings.empty?

        key = provider_class.provider_key
        missing = provider_class.required_settings.select do |setting_key|
          value = RSB::Settings.get("entitlements.providers.#{key}.#{setting_key}")
          value.nil? || value == ""
        end

        return if missing.empty?

        raise ArgumentError,
          "Provider :#{key} has required settings that are not configured: #{missing.join(', ')}"
      end
    end
  end
end
