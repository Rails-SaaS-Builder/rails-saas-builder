# frozen_string_literal: true

module RSB
  module Admin
    # Represents a custom page registration in the admin panel.
    #
    # PageRegistration is an immutable data structure that describes a custom admin
    # page (not a resource-based CRUD interface). It handles page metadata, controller
    # routing, and custom actions.
    #
    # @!attribute [r] key
    #   @return [Symbol] unique identifier for this page
    # @!attribute [r] label
    #   @return [String] the human-readable page name
    # @!attribute [r] icon
    #   @return [String, nil] optional icon identifier
    # @!attribute [r] controller
    #   @return [String] the controller path (e.g., "admin/dashboard")
    # @!attribute [r] category_name
    #   @return [String] the category this page belongs to
    # @!attribute [r] actions
    #   @return [Array<Hash>] array of action definitions with :key, :label, :method, :confirm
    #
    # @example Building a simple dashboard page
    #   page = PageRegistration.build(
    #     key: :dashboard,
    #     label: "Dashboard",
    #     icon: "home",
    #     controller: "admin/dashboard",
    #     category_name: "System"
    #   )
    #
    # @example Building a page with custom actions
    #   page = PageRegistration.build(
    #     key: :usage,
    #     label: "Usage Reports",
    #     controller: "admin/usage",
    #     category_name: "Billing",
    #     actions: [
    #       { key: :index, label: "Overview" },
    #       { key: :export, label: "Export CSV", method: :post }
    #     ]
    #   )
    PageRegistration = Data.define(
      :key,           # Symbol
      :label,         # String
      :icon,          # String | nil
      :controller,    # String
      :category_name, # String
      :actions        # Array<Hash> — [{key: :index, label: "Overview"}, ...]
    )

    class PageRegistration
      # Build a PageRegistration with normalized actions.
      #
      # @param key [Symbol, String] unique identifier for the page
      # @param label [String] the display label
      # @param icon [String, nil] optional icon identifier
      # @param controller [String] the controller path
      # @param category_name [String] the category name
      # @param actions [Array<Hash>] array of action definitions (default: [])
      # @return [PageRegistration] a frozen, immutable page registration
      #
      # @example
      #   PageRegistration.build(
      #     key: :settings,
      #     label: "Settings",
      #     controller: "admin/settings",
      #     category_name: "System"
      #   )
      def self.build(key:, label:, controller:, category_name:, icon: nil, actions: [])
        new(
          key: key.to_sym,
          label: label,
          icon: icon,
          controller: controller,
          category_name: category_name,
          actions: normalize_actions(actions)
        )
      end

      # Wrap old-style Hash pages into PageRegistration for backwards compatibility.
      #
      # @param hash [Hash] legacy page hash with :key, :label, :icon, :controller, :category_name, :actions
      # @return [PageRegistration] a frozen page registration
      #
      # @example
      #   legacy = { key: :sessions, label: "Sessions", controller: "admin/sessions", category_name: "Auth" }
      #   page = PageRegistration.from_hash(legacy)
      def self.from_hash(hash)
        build(
          key: hash[:key],
          label: hash[:label],
          icon: hash[:icon],
          controller: hash[:controller],
          category_name: hash[:category_name],
          actions: hash[:actions] || []
        )
      end

      # Get all action keys for this page.
      #
      # @return [Array<Symbol>] array of action keys
      #
      # @example
      #   page.action_keys #=> [:index, :show, :export]
      def action_keys
        actions.map { |a| a[:key] }
      end

      # Find an action definition by key.
      #
      # @param key [Symbol, String] the action key to find
      # @return [Hash, nil] the action hash or nil if not found
      #
      # @example
      #   action = page.find_action(:export)
      #   action[:method] #=> :post
      def find_action(key)
        actions.find { |a| a[:key] == key.to_sym }
      end

      # Normalize action definitions with defaults.
      #
      # @param actions [Array<Hash>] raw action definitions
      # @return [Array<Hash>] normalized action hashes
      # @api private
      private_class_method def self.normalize_actions(actions)
        actions.map do |action|
          {
            key: action[:key].to_sym,
            label: action[:label] || action[:key].to_s.humanize,
            method: (action[:method] || :get).to_sym,
            confirm: action[:confirm]
          }
        end
      end
    end
  end
end
