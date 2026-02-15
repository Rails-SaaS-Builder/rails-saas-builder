# frozen_string_literal: true

module RSB
  module Admin
    # View helper methods for rendering Lucide icons in admin panel views.
    #
    # This helper is automatically included in all RSB::Admin controllers
    # via the AdminController base class.
    #
    # @example In a view
    #   <%= rsb_admin_icon("users") %>
    #   <%= rsb_admin_icon("home", size: 24, css_class: "text-blue-500") %>
    module IconsHelper
      # Render a Lucide icon SVG with optional CSS class.
      #
      # Wraps {RSB::Admin::Icons.render} and optionally injects a CSS class
      # into the SVG tag. The class value is HTML-escaped to prevent XSS.
      # If the icon is not found, returns an empty string (no error - rule #9).
      #
      # @param name [String, Symbol] The icon name (e.g., "users", :home)
      # @param size [Integer] The width and height of the icon in pixels
      # @param css_class [String, nil] Optional CSS class to add to the SVG tag
      #
      # @return [ActiveSupport::SafeBuffer] HTML-safe SVG string with optional class, or empty string if icon not found
      #
      # @example Basic usage
      #   rsb_admin_icon("users")
      #   # => '<svg xmlns="..." width="18" height="18" ...>...</svg>'
      #
      # @example With custom size
      #   rsb_admin_icon("home", size: 24)
      #   # => '<svg xmlns="..." width="24" height="24" ...>...</svg>'
      #
      # @example With CSS class
      #   rsb_admin_icon("settings", css_class: "icon-lg text-gray-600")
      #   # => '<svg class="icon-lg text-gray-600" xmlns="..." ...>...</svg>'
      #
      # @example Unknown icon returns empty string
      #   rsb_admin_icon("nonexistent")
      #   # => ""
      #
      # @example XSS-safe (class is HTML-escaped)
      #   rsb_admin_icon("users", css_class: '"><script>alert("xss")</script>')
      #   # => '<svg class="&quot;&gt;&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;" ...>...</svg>'
      def rsb_admin_icon(name, size: 18, css_class: nil)
        svg = RSB::Admin::Icons.render(name, size: size)
        if css_class && svg.present?
          svg.sub('<svg ', "<svg class=\"#{ERB::Util.html_escape(css_class)}\" ").html_safe
        else
          svg
        end
      end
    end
  end
end
