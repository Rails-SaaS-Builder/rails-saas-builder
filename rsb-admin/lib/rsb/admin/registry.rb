module RSB
  module Admin
    class Registry
      attr_reader :categories, :dashboard_page

      def initialize
        @categories = {}
        @dashboard_page = nil
      end

      # Register a category with resources and pages
      def register_category(name, &block)
        category = @categories[name] ||= CategoryRegistration.new(name)
        category.instance_eval(&block) if block_given?
        category
      end

      # Register resources into an existing category
      def register_in(category_name, &block)
        register_category(category_name, &block)
      end

      # Register a pre-built CategoryRegistration object
      def register(category_registration)
        name = category_registration.name
        if @categories[name]
          @categories[name].merge(category_registration)
        else
          @categories[name] = category_registration
        end
      end

      # Register a custom dashboard page override.
      #
      # When registered, the built-in dashboard controller dispatches to the
      # custom controller instead of rendering the default view. Calling this
      # method multiple times replaces the previous registration (last-write-wins).
      #
      # @param controller [String] the controller path (e.g., "admin/dashboard")
      # @param actions [Array<Hash>] optional action definitions for tab navigation
      #   (e.g., `[{ key: :index, label: "Overview" }, { key: :metrics, label: "Metrics" }]`)
      #
      # @return [PageRegistration] the created dashboard page registration
      #
      # @raise [ArgumentError] if controller is blank
      #
      # @example Simple override
      #   registry.register_dashboard(controller: "admin/dashboard")
      #
      # @example Override with tab actions
      #   registry.register_dashboard(
      #     controller: "admin/dashboard",
      #     actions: [
      #       { key: :index, label: "Overview" },
      #       { key: :metrics, label: "Metrics" }
      #     ]
      #   )
      def register_dashboard(controller:, actions: [])
        raise ArgumentError, "controller must be present" if controller.nil? || controller.to_s.strip.empty?

        @dashboard_page = PageRegistration.build(
          key: :dashboard,
          label: "Dashboard",
          icon: "home",
          controller: controller,
          category_name: "System",
          actions: actions
        )
      end

      # Query
      def find_resource(model_class)
        @categories.each_value do |cat|
          resource = cat.find_resource(model_class)
          return resource if resource
        end
        nil
      end

      def find_resource_by_route_key(key)
        all_resources.find { |r| r.route_key == key }
      end

      def find_page_by_key(key)
        key_sym = key.to_sym
        categories.each_value do |category|
          category.pages.each do |page|
            return page if page.key == key_sym
          end
        end
        nil
      end

      def category?(name)
        @categories.key?(name)
      end

      def all_resources
        @categories.values.flat_map(&:resources)
      end

      def all_pages
        @categories.values.flat_map(&:pages)
      end
    end
  end
end
