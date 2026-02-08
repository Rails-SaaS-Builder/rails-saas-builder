module RSB
  module Admin
    # Represents a theme definition for the admin panel.
    #
    # ThemeDefinition is an immutable data structure that describes a visual theme
    # for the admin interface, including CSS, JavaScript, and optional view overrides.
    #
    # @!attribute [r] key
    #   @return [Symbol] unique theme identifier (e.g., :default, :modern)
    # @!attribute [r] label
    #   @return [String] the human-readable theme name
    # @!attribute [r] css
    #   @return [String] the asset path for the theme's CSS file
    # @!attribute [r] js
    #   @return [String, nil] optional asset path for the theme's JavaScript file
    # @!attribute [r] views_path
    #   @return [String, nil] optional view override path prefix
    #
    # @example Building a minimal theme
    #   theme = ThemeDefinition.new(
    #     key: :default,
    #     label: "Default Theme",
    #     css: "rsb/admin/themes/default",
    #     js: nil,
    #     views_path: nil
    #   )
    #
    # @example Building a full-featured theme
    #   theme = ThemeDefinition.new(
    #     key: :modern,
    #     label: "Modern Theme",
    #     css: "rsb/admin/themes/modern",
    #     js: "rsb/admin/themes/modern",
    #     views_path: "rsb/admin/themes/modern/views"
    #   )
    ThemeDefinition = Data.define(
      :key,        # Symbol — :default, :modern, or custom
      :label,      # String
      :css,        # String — asset path
      :js,         # String | nil — asset path for optional JS
      :views_path  # String | nil — view override path prefix
    )
  end
end
