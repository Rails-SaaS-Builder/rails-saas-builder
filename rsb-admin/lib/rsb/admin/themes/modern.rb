module RSB
  module Admin
    module Themes
      # Self-contained registration for the Modern theme.
      #
      # This module encapsulates all registration logic for the built-in Modern
      # theme. It exists as a clear boundary so the modern theme can eventually
      # be extracted to a separate gem (`rsb-admin-modern-theme`).
      #
      # To extract to a separate gem:
      # 1. Move this module + assets + views to rsb-admin-modern-theme gem
      # 2. Replace the call in RSB::Admin.register_built_in_themes with a
      #    dependency on the new gem
      # 3. The gem's engine calls RSB::Admin::Themes::Modern.register! in
      #    an initializer
      #
      # @example Register the modern theme
      #   RSB::Admin::Themes::Modern.register!
      module Modern
        # Registers the Modern theme with RSB::Admin.
        #
        # This method registers the theme definition including CSS (with dark
        # mode support), JavaScript (toggle + persistence), and view overrides
        # (sidebar, header).
        #
        # @return [RSB::Admin::ThemeDefinition] the registered theme definition
        #
        # @example
        #   RSB::Admin::Themes::Modern.register!
        #   RSB::Admin.themes[:modern]
        #   # => #<data RSB::Admin::ThemeDefinition key=:modern, ...>
        def self.register!
          RSB::Admin.register_theme :modern,
            label: "Modern",
            css: "rsb/admin/themes/modern",
            js: "rsb/admin/themes/modern",
            views_path: "rsb/admin/themes/modern/views"
        end
      end
    end
  end
end
