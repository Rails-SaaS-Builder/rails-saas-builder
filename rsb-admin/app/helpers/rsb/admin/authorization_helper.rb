# frozen_string_literal: true

module RSB
  module Admin
    # View helper for permission-aware rendering in admin views.
    #
    # Provides a convenience method to check if the current admin user
    # has permission to access a given resource and action. Used in views
    # to conditionally render or disable UI elements based on RBAC permissions.
    # This helper is automatically included in all RSB::Admin controllers
    # via the AdminController base class.
    #
    # @example Check permission in a view
    #   <% if rsb_admin_can?("identities", "index") %>
    #     <a href="/admin/identities">Identities</a>
    #   <% end %>
    #
    # @example Conditionally render action button
    #   <% if rsb_admin_can?("articles", "edit") %>
    #     <%= link_to "Edit", edit_admin_article_path(@article) %>
    #   <% end %>
    module AuthorizationHelper
      # Check if the current admin user has permission for a resource action.
      #
      # Delegates to `current_admin_user.can?` for the actual permission check.
      # Returns false if there is no current admin user (safety fallback).
      #
      # @param resource [String] the resource key (e.g., "identities", "dashboard")
      # @param action [String] the action name (e.g., "index", "show", "edit")
      #
      # @return [Boolean] true if the user has permission, false otherwise
      #
      # @example Check dashboard access
      #   rsb_admin_can?("dashboard", "index") #=> true/false
      #
      # @example Check resource edit permission
      #   rsb_admin_can?("identities", "edit") #=> true/false
      #
      # @example No current user returns false
      #   # When current_admin_user is nil
      #   rsb_admin_can?("roles", "index") #=> false
      def rsb_admin_can?(resource, action)
        return false unless respond_to?(:current_admin_user) && current_admin_user

        current_admin_user.can?(resource, action)
      end
    end
  end
end
