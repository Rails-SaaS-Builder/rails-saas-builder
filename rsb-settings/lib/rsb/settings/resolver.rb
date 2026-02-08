module RSB
  module Settings
    class Resolver
      def initialize(registry:, configuration:)
        @registry = registry
        @configuration = configuration
        @cache = {}
      end

      def get(category, key)
        cache_key = "#{category}.#{key}"
        return @cache[cache_key] if @cache.key?(cache_key)

        value = resolve(category, key)
        @cache[cache_key] = value
        value
      end

      def set(category, key, value)
        full_key = "#{category}.#{key}"
        old_value = get(category, key)
        new_value = value

        Setting.transaction do
          Setting.set(category, key, value)
          invalidate(category, key)
          @registry.fire_change(full_key, old_value, new_value)
        end

        new_value
      end

      def for(category)
        schema = @registry.for(category)
        return {} unless schema

        schema.definitions.each_with_object({}) do |defn, hash|
          hash[defn.key] = get(category, defn.key.to_s)
        end
      end

      def invalidate(category = nil, key = nil)
        if category && key
          @cache.delete("#{category}.#{key}")
        else
          @cache.clear
        end
      end

      private

      def resolve(category, key)
        definition = @registry.find_definition("#{category}.#{key}")

        # 1. Database (admin panel / runtime override)
        db_value = Setting.get(category, key)
        return cast(db_value, definition) if db_value.present?

        # 2. Initializer (code-level config overrides)
        init_value = @configuration.initializer_value(category, key)
        return init_value unless init_value.nil?

        # 3. Environment variable (RSB_AUTH_REGISTRATION_MODE)
        env_key = "RSB_#{category.to_s.upcase}_#{key.to_s.upcase}"
        env_value = ENV[env_key]
        return cast(env_value, definition) if env_value.present?

        # 4. Default (from schema definition)
        definition&.default
      end

      def cast(value, definition)
        return value unless definition
        return value unless value.is_a?(String)

        case definition.type
        when :integer then value.to_i
        when :float then value.to_f
        when :boolean then ActiveModel::Type::Boolean.new.cast(value)
        when :symbol then value.to_sym
        when :string then value.to_s
        when :array then value.is_a?(Array) ? value : value.split(",").map(&:strip)
        when :duration then value.to_i.seconds
        else value
        end
      end
    end
  end
end
