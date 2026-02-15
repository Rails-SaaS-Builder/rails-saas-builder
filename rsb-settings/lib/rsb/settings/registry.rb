# frozen_string_literal: true

module RSB
  module Settings
    class Registry
      attr_reader :schemas, :change_callbacks

      def initialize
        @schemas = {}
        @change_callbacks = {}
      end

      # Register a schema (from a gem's pure-data definition)
      def register(schema)
        raise ArgumentError, "Expected RSB::Settings::Schema, got #{schema.class}" unless schema.is_a?(Schema)

        @schemas[schema.category] = if @schemas[schema.category]
                                      @schemas[schema.category].merge(schema)
                                    else
                                      schema
                                    end
      end

      # Convenience: define and register in one step
      def define(category, &block)
        schema = Schema.new(category, &block)
        register(schema)
        schema
      end

      # Query
      def for(category)
        @schemas[category.to_s]
      end

      def all
        @schemas.values
      end

      def categories
        @schemas.keys
      end

      def find_definition(key)
        category, setting_key = key.to_s.split('.', 2)
        @schemas[category]&.find(setting_key)
      end

      # Returns definitions for a category grouped by the `group` field.
      # Settings with a nil group are placed under "General".
      # "General" always appears first if present, followed by other groups
      # in the order their first setting was registered.
      #
      # @param category [String] the settings category name
      # @return [Hash<String, Array<SettingDefinition>>] ordered hash of group name to definitions
      # @example
      #   registry.grouped_definitions("auth")
      #   # => { "General" => [defn1], "Session & Security" => [defn2, defn3], "Registration" => [defn4] }
      def grouped_definitions(category)
        schema = @schemas[category.to_s]
        return {} unless schema

        groups = {}
        schema.definitions.each do |defn|
          group_name = defn.group || 'General'
          groups[group_name] ||= []
          groups[group_name] << defn
        end

        # Ensure "General" is first if present
        return groups unless groups.key?('General') && groups.keys.first != 'General'

        general = groups.delete('General')
        { 'General' => general }.merge(groups)
      end

      # Change callbacks
      def on_change(key, &block)
        @change_callbacks[key.to_s] ||= []
        @change_callbacks[key.to_s] << block
      end

      def fire_change(key, old_value, new_value)
        callbacks = @change_callbacks[key.to_s] || []
        callbacks.each { |cb| cb.call(old_value, new_value) }
      end
    end
  end
end
