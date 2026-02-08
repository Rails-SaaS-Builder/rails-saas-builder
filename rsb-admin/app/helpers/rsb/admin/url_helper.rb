module RSB
  module Admin
    # Dynamic URL helpers for admin resource and page paths.
    #
    # These helpers derive all URLs from the engine mount point (extracted from
    # rsb_admin.dashboard_path) so they work correctly regardless of where the
    # engine is mounted. They replace hardcoded "/admin/..." strings throughout
    # views and controllers.
    #
    # @example In a view
    #   rsb_admin_resource_path("identities")         # => "/admin/identities"
    #   rsb_admin_resource_show_path("identities", 42) # => "/admin/identities/42"
    #
    module UrlHelper
      # Generate the index path for a resource.
      #
      # @param route_key [String] the resource's route key (e.g., "identities")
      # @return [String] e.g., "/admin/identities"
      #
      # @example
      #   rsb_admin_resource_path("identities") # => "/admin/identities"
      def rsb_admin_resource_path(route_key)
        "#{rsb_admin_base_path}#{route_key}"
      end

      # Generate the show path for a specific resource record.
      #
      # @param route_key [String]
      # @param id [Integer, String]
      # @return [String] e.g., "/admin/identities/42"
      #
      # @example
      #   rsb_admin_resource_show_path("identities", 42) # => "/admin/identities/42"
      def rsb_admin_resource_show_path(route_key, id)
        "#{rsb_admin_base_path}#{route_key}/#{id}"
      end

      # Generate the new path for creating a resource record.
      #
      # @param route_key [String]
      # @return [String] e.g., "/admin/identities/new"
      #
      # @example
      #   rsb_admin_resource_new_path("identities") # => "/admin/identities/new"
      def rsb_admin_resource_new_path(route_key)
        "#{rsb_admin_base_path}#{route_key}/new"
      end

      # Generate the edit path for a specific resource record.
      #
      # @param route_key [String]
      # @param id [Integer, String]
      # @return [String] e.g., "/admin/identities/42/edit"
      #
      # @example
      #   rsb_admin_resource_edit_path("identities", 42) # => "/admin/identities/42/edit"
      def rsb_admin_resource_edit_path(route_key, id)
        "#{rsb_admin_base_path}#{route_key}/#{id}/edit"
      end

      # Generate the path for a static page.
      #
      # @param page_key [String, Symbol]
      # @return [String] e.g., "/admin/active_sessions"
      #
      # @example
      #   rsb_admin_page_path("active_sessions") # => "/admin/active_sessions"
      def rsb_admin_page_path(page_key)
        "#{rsb_admin_base_path}#{page_key}"
      end

      # Generate the path for a static page action.
      #
      # @param page_key [String, Symbol]
      # @param action_key [String, Symbol]
      # @return [String] e.g., "/admin/active_sessions/by_user"
      #
      # @example
      #   rsb_admin_page_action_path("active_sessions", "by_user") # => "/admin/active_sessions/by_user"
      def rsb_admin_page_action_path(page_key, action_key)
        "#{rsb_admin_base_path}#{page_key}/#{action_key}"
      end

      # Generate the path for a dashboard sub-action.
      #
      # @param action_key [String, Symbol] the action key (e.g., "metrics")
      # @return [String] e.g., "/admin/dashboard/metrics"
      #
      # @example
      #   rsb_admin_dashboard_action_path("metrics") # => "/admin/dashboard/metrics"
      def rsb_admin_dashboard_action_path(action_key)
        "#{rsb_admin_base_path}dashboard/#{action_key}"
      end

      private

      # Extract the engine mount point from the dashboard path.
      # Returns the mount point with trailing slash (e.g., "/admin/").
      #
      # @return [String] the engine mount point with trailing slash
      # @api private
      def rsb_admin_base_path
        @rsb_admin_base_path ||= rsb_admin.dashboard_path.chomp('dashboard')
      end
    end
  end
end
