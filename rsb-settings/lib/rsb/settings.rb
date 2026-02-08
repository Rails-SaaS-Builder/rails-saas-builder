require "active_support/inflector"
ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.acronym "RSB" }

require "rsb/settings/version"
require "rsb/settings/engine"
require "rsb/settings/schema"
require "rsb/settings/registry"
require "rsb/settings/resolver"
require "rsb/settings/configuration"
require "rsb/settings/validation_error"
require "rsb/settings/locale_helper"
require "rsb/settings/locale_middleware"
require "rsb/settings/seo_settings_schema"
require "rsb/settings/seo_helper"

module RSB
  module Settings
    class << self
      # --- Instance-based registry (resettable for tests) ---

      def registry
        @registry ||= Registry.new
      end

      # --- Public API ---

      def get(key)
        category, setting_key = parse_key(key)
        resolver.get(category, setting_key)
      end

      def set(key, value)
        category, setting_key = parse_key(key)
        resolver.set(category, setting_key, value)
      end

      def for(category)
        resolver.for(category)
      end

      # --- Configuration (locks, initializer overrides) ---

      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      # Clear the resolver cache. Use after a transaction rollback
      # to prevent stale cached values from being returned.
      #
      # @return [void]
      def invalidate_cache!
        resolver.invalidate
      end

      # --- Locale configuration ---

      def available_locales
        configuration.available_locales
      end

      def default_locale
        configuration.default_locale
      end

      def locale_display_name(code)
        configuration.locale_display_names[code.to_s] || code.to_s
      end

      def locale_display_names
        configuration.locale_display_names
      end

      # --- Test support ---

      def reset!
        @registry = Registry.new
        @resolver = nil
        @configuration = Configuration.new
      end

      private

      def resolver
        @resolver ||= Resolver.new(registry: registry, configuration: configuration)
      end

      def parse_key(key)
        parts = key.to_s.split(".", 2)
        raise ArgumentError, "Key must be in 'category.key' format, got: #{key}" if parts.size != 2
        parts
      end
    end
  end
end
