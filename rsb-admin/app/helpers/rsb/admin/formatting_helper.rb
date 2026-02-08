module RSB
  module Admin
    # View helper methods for formatting values and rendering badges in admin panel views.
    #
    # This helper provides value formatting utilities for displaying data in tables,
    # forms, and detail views. It includes badge rendering with auto-detected variants
    # and support for multiple formatter types (datetime, json, truncate, custom procs).
    # The helper is automatically included in all RSB::Admin controllers via the
    # AdminController base class.
    #
    # @example Badge rendering
    #   <%= rsb_admin_badge("Active", variant: :success) %>
    #   <%= rsb_admin_badge(user.status, variant: :info) %>
    #
    # @example Value formatting
    #   <%= rsb_admin_format_value(user.status, :badge) %>
    #   <%= rsb_admin_format_value(user.created_at, :datetime) %>
    #   <%= rsb_admin_format_value(user.metadata, :json) %>
    module FormattingHelper
      # Render a badge span with auto-detected or explicit variant.
      #
      # Badges are styled spans with background and text colors corresponding to
      # semantic variants (success, warning, danger, info). The badge uses Tailwind
      # CSS utility classes with rsb-* prefixed custom color tokens.
      #
      # @param text [String, #to_s] The badge text content
      # @param variant [Symbol] The badge variant (:success, :warning, :danger, :info)
      #   Defaults to :info
      #
      # @return [ActiveSupport::SafeBuffer] HTML-safe badge span element
      #
      # @example Success badge
      #   rsb_admin_badge("Active", variant: :success)
      #   # => '<span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-rsb-success-bg text-rsb-success-text">Active</span>'
      #
      # @example Warning badge
      #   rsb_admin_badge("Pending", variant: :warning)
      #   # => '<span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-rsb-warning-bg text-rsb-warning-text">Pending</span>'
      #
      # @example Danger badge
      #   rsb_admin_badge("Expired", variant: :danger)
      #   # => '<span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-rsb-danger-bg text-rsb-danger-text">Expired</span>'
      #
      # @example Info badge (default)
      #   rsb_admin_badge("Unknown")
      #   # => '<span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-rsb-info-bg text-rsb-info-text">Unknown</span>'
      def rsb_admin_badge(text, variant: :info)
        variant_class = case variant.to_s
                        when "success" then "bg-rsb-success-bg text-rsb-success-text"
                        when "warning" then "bg-rsb-warning-bg text-rsb-warning-text"
                        when "danger"  then "bg-rsb-danger-bg text-rsb-danger-text"
                        else "bg-rsb-info-bg text-rsb-info-text"
                        end
        content_tag(:span, text, class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{variant_class}")
      end

      # Format a value using a formatter strategy.
      #
      # This method provides a unified interface for formatting values in admin views.
      # It supports built-in formatters (:badge, :datetime, :truncate, :json), custom
      # proc formatters, and intelligent defaults when no formatter is specified.
      # Returns HTML-safe strings suitable for direct rendering in views.
      #
      # @param value [Object] The value to format (can be nil, String, Time, Hash, Array, etc.)
      # @param formatter [Symbol, Proc, nil] The formatter to use:
      #   - :badge — renders as badge with auto-detected variant (rule #4)
      #   - :datetime — formats Time values as "Month DD, YYYY at HH:MM PM"
      #   - :truncate — truncates to 50 chars with ellipsis
      #   - :json — pretty-prints Hash/Array as <pre> block
      #   - Proc — calls proc with (value) or (value, record) based on arity
      #   - nil — auto-formats based on value type
      # @param record [Object, nil] Optional record passed to proc formatters with arity 2
      #
      # @return [ActiveSupport::SafeBuffer, String] HTML-safe formatted value
      #
      # @example Badge with auto-detection (rule #4)
      #   rsb_admin_format_value("active", :badge)
      #   # => '<span class="...bg-rsb-success-bg...">Active</span>'
      #   rsb_admin_format_value("suspended", :badge)
      #   # => '<span class="...bg-rsb-warning-bg...">Suspended</span>'
      #
      # @example Datetime formatting
      #   rsb_admin_format_value(Time.new(2024, 6, 15, 14, 30), :datetime)
      #   # => "June 15, 2024 at 02:30 PM"
      #
      # @example Truncate long text
      #   rsb_admin_format_value("a" * 100, :truncate)
      #   # => "aaaaaaaaaa... (truncated)"
      #
      # @example JSON formatting
      #   rsb_admin_format_value({ foo: "bar", baz: 123 }, :json)
      #   # => '<pre class="...">{\n  "foo": "bar",\n  "baz": 123\n}</pre>'
      #
      # @example Empty JSON
      #   rsb_admin_format_value({}, :json)
      #   # => '<span class="text-rsb-muted">Empty</span>'
      #
      # @example Custom proc formatter
      #   formatter = ->(val) { "USD #{val}" }
      #   rsb_admin_format_value(100, formatter)
      #   # => "USD 100"
      #
      # @example Proc with record
      #   formatter = ->(val, rec) { "#{val} for #{rec.name}" }
      #   rsb_admin_format_value("admin", formatter, user)
      #   # => "admin for John Doe"
      #
      # @example Nil value
      #   rsb_admin_format_value(nil, nil)
      #   # => '<span class="text-rsb-muted">-</span>'
      #
      # @example XSS prevention
      #   rsb_admin_format_value("<script>alert('xss')</script>", nil)
      #   # => "&lt;script&gt;alert('xss')&lt;/script&gt;"
      def rsb_admin_format_value(value, formatter, record = nil)
        return content_tag(:span, "-", class: "text-rsb-muted") if value.nil?

        case formatter
        when :badge
          variant = auto_badge_variant(value)
          rsb_admin_badge(value.to_s.titleize, variant: variant)
        when :datetime
          if value.respond_to?(:strftime)
            value.strftime("%B %d, %Y at %I:%M %p")
          else
            value.to_s
          end
        when :truncate
          truncate(value.to_s, length: 50)
        when :json
          if value.is_a?(Hash) || value.is_a?(Array)
            if value.empty?
              content_tag(:span, "Empty", class: "text-rsb-muted")
            else
              content_tag(:pre, JSON.pretty_generate(value),
                class: "mt-1 p-3 bg-rsb-bg rounded-rsb text-xs font-mono overflow-x-auto whitespace-pre")
            end
          else
            value.to_s
          end
        when Proc
          result = formatter.arity == 2 ? formatter.call(value, record) : formatter.call(value)
          result.to_s
        when nil
          # No formatter — render as-is, with special handling for known types
          if (value.is_a?(Hash) || value.is_a?(Array)) && value.any?
            content_tag(:pre, JSON.pretty_generate(value),
              class: "mt-1 p-3 bg-rsb-bg rounded-rsb text-xs font-mono overflow-x-auto whitespace-pre")
          elsif value.is_a?(Time)
            value.strftime("%B %d, %Y at %I:%M %p")
          else
            ERB::Util.html_escape(value.to_s)
          end
        else
          ERB::Util.html_escape(value.to_s)
        end
      end

      private

      # Auto-detect badge variant from status-like values (rule #4).
      #
      # This method implements the badge auto-detection logic for common status
      # strings. It performs case-insensitive matching against predefined status
      # categories and returns the corresponding semantic variant.
      #
      # @param value [#to_s] The value to analyze (typically a status string)
      #
      # @return [Symbol] The detected variant (:success, :warning, :danger, or :info)
      #
      # @example Success states
      #   auto_badge_variant("active")     # => :success
      #   auto_badge_variant("ENABLED")    # => :success
      #   auto_badge_variant("confirmed")  # => :success
      #
      # @example Warning states
      #   auto_badge_variant("pending")    # => :warning
      #   auto_badge_variant("SUSPENDED")  # => :warning
      #   auto_badge_variant("invited")    # => :warning
      #
      # @example Danger states
      #   auto_badge_variant("expired")    # => :danger
      #   auto_badge_variant("DELETED")    # => :danger
      #   auto_badge_variant("banned")     # => :danger
      #
      # @example Unknown states (fallback)
      #   auto_badge_variant("unknown")    # => :info
      #   auto_badge_variant("custom")     # => :info
      def auto_badge_variant(value)
        case value.to_s.downcase
        when "active", "enabled", "confirmed", "accepted"
          :success
        when "suspended", "pending", "invited", "expiring"
          :warning
        when "deactivated", "disabled", "expired", "revoked", "banned", "deleted"
          :danger
        else
          :info
        end
      end
    end
  end
end
