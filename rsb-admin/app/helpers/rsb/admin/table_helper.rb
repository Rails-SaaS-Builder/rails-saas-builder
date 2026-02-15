# frozen_string_literal: true

module RSB
  module Admin
    # View helper methods for generating sortable table links and preserving filter state.
    #
    # This helper provides utilities for building sort links that cycle through
    # sort states (asc → desc → none) and preserve existing filter parameters
    # in the URL. The helper is automatically included in all RSB::Admin
    # controllers via the AdminController base class.
    #
    # @example In a view
    #   <% columns.each do |col| %>
    #     <% if col.sortable %>
    #       <a href="<%= sort_link(col) %>"><%= col.label %></a>
    #     <% else %>
    #       <%= col.label %>
    #     <% end %>
    #   <% end %>
    module TableHelper
      # Build a sort link URL for a sortable column.
      #
      # This method generates a URL that includes sort and direction parameters,
      # and preserves any existing filter query parameters. The sort direction
      # cycles through three states when clicking the same column repeatedly:
      # 1. No sort → asc
      # 2. asc → desc
      # 3. desc → no sort (removes sort parameters)
      #
      # When clicking a different column, it always starts with asc direction.
      #
      # @param column [ColumnDefinition] the column definition object
      #
      # @return [String] the URL with sort parameters and preserved filters
      #
      # @example First click on a column (no sort → asc)
      #   sort_link(column)
      #   # => "/admin/users?sort=email&dir=asc"
      #
      # @example Second click on same column (asc → desc)
      #   # Given: params[:sort] = "email", params[:dir] = "asc"
      #   sort_link(column)
      #   # => "/admin/users?sort=email&dir=desc"
      #
      # @example Third click on same column (desc → none)
      #   # Given: params[:sort] = "email", params[:dir] = "desc"
      #   sort_link(column)
      #   # => "/admin/users"
      #
      # @example Preserves existing filters
      #   # Given: params[:q] = { status: "active" }, params[:sort] = "email", params[:dir] = "asc"
      #   sort_link(column)
      #   # => "/admin/users?sort=email&dir=desc&q[status]=active"
      #
      # @example Clicking different column resets to asc
      #   # Given: params[:sort] = "email", params[:dir] = "desc"
      #   sort_link(name_column)
      #   # => "/admin/users?sort=name&dir=asc"
      def sort_link(column)
        current_sort = params[:sort]
        current_dir = params[:dir]

        # Determine new direction based on current state
        new_dir = if current_sort == column.key.to_s
                    # Clicking same column: cycle through asc → desc → none
                    case current_dir
                    when 'asc'
                      'desc'
                    when 'desc'
                      nil # Remove sort
                    else
                      'asc'
                    end
                  else
                    # Clicking different column: start with asc
                    'asc'
                  end

        # Build URL with or without sort parameters
        if new_dir
          "#{request.path}?sort=#{column.key}&dir=#{new_dir}#{filter_query_string}"
        elsif filter_query_string.present?
          # No sort - just path + filters
          "#{request.path}#{filter_query_string}"
        else
          request.path
        end
      end

      private

      # Build a query string from filter parameters.
      #
      # This method extracts filter parameters from `params[:q]` and converts
      # them into a URL-encoded query string that can be appended to URLs.
      # The query string is prefixed with "&" for easy concatenation with
      # existing parameters.
      #
      # Special characters in filter values are properly URL-encoded to prevent
      # issues with spaces, ampersands, and other special characters.
      #
      # @return [String] the URL-encoded query string prefixed with "&", or empty string if no filters
      #
      # @example No filters
      #   filter_query_string
      #   # => ""
      #
      # @example Single filter
      #   # Given: params[:q] = { status: "active" }
      #   filter_query_string
      #   # => "&q[status]=active"
      #
      # @example Multiple filters
      #   # Given: params[:q] = { status: "active", email: "test@example.com" }
      #   filter_query_string
      #   # => "&q[status]=active&q[email]=test%40example.com"
      #
      # @example Special characters are URL-encoded
      #   # Given: params[:q] = { title: "test & value" }
      #   filter_query_string
      #   # => "&q[title]=test+%26+value"
      #
      # @api private
      def filter_query_string
        return '' unless params[:q].present?

        filter_hash = params[:q].respond_to?(:to_unsafe_h) ? params[:q].to_unsafe_h : params[:q]
        '&' + filter_hash.map { |k, v| "q[#{k}]=#{ERB::Util.url_encode(v)}" }.join('&')
      end
    end
  end
end
