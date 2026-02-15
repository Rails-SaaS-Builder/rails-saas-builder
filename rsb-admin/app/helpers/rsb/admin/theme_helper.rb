# frozen_string_literal: true

module RSB
  module Admin
    # View helper methods for theme-aware partial resolution in admin panel views.
    #
    # This helper provides a partial resolution system that follows a 3-level
    # override chain, allowing host applications and themes to override engine
    # default views. The helper is automatically included in all RSB::Admin
    # controllers via the AdminController base class.
    #
    # @see RSB::Admin::Configuration#view_overrides_path
    # @see RSB::Admin::Configuration#theme
    # @see RSB::Admin::ThemeDefinition
    #
    # @example In a view
    #   <%= render rsb_admin_partial("shared/sidebar") %>
    #   # Resolves to first match:
    #   # 1. app/views/admin_overrides/shared/_sidebar.html.erb (if view_overrides_path set)
    #   # 2. app/views/rsb/admin/themes/modern/views/shared/_sidebar.html.erb (if theme has views_path)
    #   # 3. rsb-admin/app/views/rsb/admin/shared/_sidebar.html.erb (engine default)
    module ThemeHelper
      # Resolves a partial path through the theme override chain.
      #
      # This method implements the view override resolution order (rule #16):
      # 1. Host app override path (highest priority)
      # 2. Theme override path
      # 3. Engine default (fallback)
      #
      # The resolved path is returned as a string suitable for passing to `render`.
      # This method is designed to be used with the `render` helper in views (rule #14).
      #
      # @param name [String] The partial name without leading underscore or extension
      #   (e.g., "shared/sidebar", "users/form")
      #
      # @return [String] The resolved partial path
      #
      # @example Basic usage (no overrides)
      #   rsb_admin_partial("shared/sidebar")
      #   # => "rsb/admin/shared/sidebar"
      #
      # @example With host app override
      #   # Given: RSB::Admin.configuration.view_overrides_path = "admin_overrides"
      #   # And file exists: app/views/admin_overrides/shared/_sidebar.html.erb
      #   rsb_admin_partial("shared/sidebar")
      #   # => "admin_overrides/shared/sidebar"
      #
      # @example With theme override
      #   # Given: RSB::Admin.configuration.theme = :modern
      #   # And theme.views_path = "rsb/admin/themes/modern/views"
      #   # And file exists: app/views/rsb/admin/themes/modern/views/shared/_sidebar.html.erb
      #   rsb_admin_partial("shared/sidebar")
      #   # => "rsb/admin/themes/modern/views/shared/sidebar"
      #
      # @example Priority order
      #   # Host app override takes precedence over theme override
      #   # Theme override takes precedence over engine default
      #   rsb_admin_partial("users/form")
      #   # Checks in order:
      #   # 1. admin_overrides/users/_form.html.erb
      #   # 2. rsb/admin/themes/modern/views/users/_form.html.erb
      #   # 3. rsb/admin/users/_form.html.erb (always returned as fallback)
      def rsb_admin_partial(name)
        override_path = RSB::Admin.configuration.view_overrides_path
        theme = RSB::Admin.current_theme

        # 1. Host app override (highest priority)
        if override_path
          candidate = "#{override_path}/#{name}"
          return candidate if lookup_context.exists?(candidate, [], true)
        end

        # 2. Theme override
        if theme&.views_path
          candidate = "#{theme.views_path}/#{name}"
          return candidate if lookup_context.exists?(candidate, [], true)
        end

        # 3. Engine default (fallback)
        "rsb/admin/#{name}"
      end
    end
  end
end
