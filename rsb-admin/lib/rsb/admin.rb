require "rsb/settings"
require "rotp"
require "rqrcode"
require "rsb/admin/version"
require "rsb/admin/engine"
require "rsb/admin/configuration"
require "rsb/admin/registry"
require "rsb/admin/resource_registration"
require "rsb/admin/category_registration"
require "rsb/admin/column_definition"
require "rsb/admin/filter_definition"
require "rsb/admin/form_field_definition"
require "rsb/admin/page_registration"
require "rsb/admin/resource_dsl_context"
require "rsb/admin/breadcrumb_item"
require "rsb/admin/theme_definition"
require "rsb/admin/settings_schema"
require "rsb/admin/icons"
require "rsb/admin/themes/modern"

module RSB
  module Admin
    class << self
      def registry
        @registry ||= Registry.new
      end

      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def settings_schema
        @settings_schema ||= SettingsSchema.build
      end

      # Registers a theme definition.
      #
      # Themes are stored in a module-level hash and can be referenced by
      # their key symbol. Use this to register custom themes or override
      # built-in themes.
      #
      # @param key [Symbol, String] the unique theme identifier
      # @param label [String] the human-readable theme name
      # @param css [String] the asset path for the theme's CSS file
      # @param js [String, nil] optional asset path for the theme's JavaScript file
      # @param views_path [String, nil] optional view override path prefix
      #
      # @return [RSB::Admin::ThemeDefinition] the registered theme definition
      #
      # @example Register a custom theme
      #   RSB::Admin.register_theme :corporate,
      #     label: "Corporate",
      #     css: "my_app/admin/corporate",
      #     js: "my_app/admin/corporate",
      #     views_path: "my_app/admin/corporate/views"
      def register_theme(key, label:, css:, js: nil, views_path: nil)
        @themes ||= {}
        @themes[key.to_sym] = ThemeDefinition.new(
          key: key.to_sym,
          label: label,
          css: css,
          js: js,
          views_path: views_path
        )
      end

      # Returns all registered themes.
      #
      # @return [Hash{Symbol => RSB::Admin::ThemeDefinition}] a hash of theme definitions keyed by their symbol
      #
      # @example
      #   RSB::Admin.themes
      #   # => { default: #<data RSB::Admin::ThemeDefinition...>, modern: #<data...> }
      def themes
        @themes || {}
      end

      # Returns the ThemeDefinition for the currently configured theme.
      #
      # Reads from the settings DB so changes made via the admin panel
      # take effect immediately without restart.  Falls back to
      # +configuration.theme+ (initializer value) when settings are not
      # yet available, and ultimately to the +:default+ theme.
      #
      # @return [RSB::Admin::ThemeDefinition] the active theme definition
      #
      # @example
      #   RSB::Settings.set("admin", "theme", "modern")
      #   RSB::Admin.current_theme
      #   # => #<data RSB::Admin::ThemeDefinition key=:modern, ...>
      def current_theme
        theme_key = RSB::Settings.get("admin.theme").presence || configuration.theme
        themes[theme_key.to_sym] || themes[:default]
      end

      # Checks whether the admin panel is enabled.
      #
      # Uses a special resolution order for safety: ENV has highest priority
      # (overrides DB), so a developer can always force-enable via
      # RSB_ADMIN_ENABLED=true without needing database access.
      #
      # Resolution: ENV['RSB_ADMIN_ENABLED'] → DB → initializer → default (true)
      #
      # @return [Boolean] true if the admin panel is enabled
      #
      # @example
      #   RSB::Admin.enabled?  # => true (default)
      #
      # @example Force-enable via ENV
      #   ENV['RSB_ADMIN_ENABLED'] = 'true'
      #   RSB::Admin.enabled?  # => true (even if DB says false)
      def enabled?
        # ENV override has highest priority (escape hatch)
        if ENV.key?("RSB_ADMIN_ENABLED")
          return ActiveModel::Type::Boolean.new.cast(ENV["RSB_ADMIN_ENABLED"])
        end
        # Normal settings resolution: DB → initializer → default
        RSB::Settings.get("admin.enabled") != false
      end

      def reset!
        @registry = Registry.new
        @configuration = Configuration.new
        @settings_schema = nil
        @themes = {}
        register_built_in_themes
      end

      # Convenience method to render an icon SVG.
      #
      # This is a shorthand for {RSB::Admin::Icons.render}.
      # Useful when you need to render icons outside of view context.
      #
      # @param name [String, Symbol] The icon name (e.g., "users", :home)
      # @param size [Integer] The width and height of the icon in pixels
      #
      # @return [ActiveSupport::SafeBuffer] HTML-safe SVG string, or empty string if icon not found
      #
      # @example
      #   RSB::Admin.icon("users")
      #   # => '<svg xmlns="..." width="18" height="18" ...>...</svg>'
      #
      # @example
      #   RSB::Admin.icon(:home, size: 32)
      #   # => '<svg xmlns="..." width="32" height="32" ...>...</svg>'
      #
      # @see RSB::Admin::Icons.render
      def icon(name, size: 18)
        Icons.render(name, size: size)
      end

      private

      # Registers the built-in themes (default and modern).
      #
      # This is called automatically at module load time and after {#reset!}.
      #
      # @api private
      def register_built_in_themes
        register_theme :default,
          label: "Default",
          css: "rsb/admin/themes/default",
          views_path: nil

        Themes::Modern.register!
      end
    end

    # Register built-in themes at load time
    register_built_in_themes
  end
end
