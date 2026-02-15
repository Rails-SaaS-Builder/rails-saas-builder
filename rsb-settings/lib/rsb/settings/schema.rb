# frozen_string_literal: true

module RSB
  module Settings
    class Schema
      SettingDefinition = Data.define(
        :key, :type, :default, :description,
        :enum, :validates, :encrypted, :locked,
        :group, :depends_on, :label
      ) do
        def initialize(key:, type:, default:, description:, enum:, validates:, encrypted:, locked:, group: nil,
                       depends_on: nil, label: nil)
          super
        end
      end

      attr_reader :category, :definitions

      def initialize(category, &block)
        @category = category.to_s
        @definitions = []
        instance_eval(&block) if block_given?
      end

      # Define a setting within this schema.
      #
      # @param key [Symbol] setting key within the category
      # @param type [Symbol] value type (:string, :integer, :boolean, :float, :symbol, :array, :duration)
      # @param default [Object] default value (nil if not specified)
      # @param description [String] human-readable description shown in admin UI
      # @param enum [Array, Proc, nil] allowed values (static array or dynamic proc)
      # @param validates [Hash, nil] custom validation rules
      # @param encrypted [Boolean] encrypt value in schema (default: false)
      # @param locked [Boolean] lock by default, preventing runtime changes (default: false)
      # @param group [String, nil] subgroup name for admin UI grouping. nil = "General" group
      # @param depends_on [String, nil] full setting key (e.g., "auth.account_enabled") this setting depends on.
      #   When the referenced setting resolves to a falsy value, this setting is rendered disabled in the admin UI.
      # @return [void]
      def setting(key, type:, default: nil, description: '', enum: nil, validates: nil, encrypted: false,
                  locked: false, group: nil, depends_on: nil, label: nil)
        @definitions << SettingDefinition.new(
          key: key.to_sym,
          type: type.to_sym,
          default: default,
          description: description,
          enum: enum,
          validates: validates,
          encrypted: encrypted,
          locked: locked,
          group: group,
          depends_on: depends_on,
          label: label
        )
      end

      def keys
        @definitions.map(&:key)
      end

      def defaults
        @definitions.each_with_object({}) { |d, h| h[d.key] = d.default }
      end

      def find(key)
        @definitions.find { |d| d.key == key.to_sym }
      end

      def valid?
        !@category.nil? && !@category.empty? && @definitions.all? { |d| !d.key.nil? && !d.type.nil? }
      end

      def merge(other_schema)
        raise ArgumentError, 'Cannot merge schemas from different categories' unless other_schema.category == @category

        merged = Schema.new(@category)
        merged.instance_variable_set(:@definitions, @definitions + other_schema.definitions)
        merged
      end
    end
  end
end
