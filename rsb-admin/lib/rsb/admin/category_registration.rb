module RSB
  module Admin
    # Represents a category of admin resources and pages.
    #
    # Categories group related resources and pages in the admin interface sidebar.
    # Each category has a name and contains collections of resources (CRUD interfaces
    # for models) and pages (custom non-CRUD interfaces).
    #
    # @!attribute [r] name
    #   @return [String] the category name
    #
    # @!attribute [r] resources
    #   @return [Array<ResourceRegistration>] registered resources in this category
    #
    # @!attribute [r] pages
    #   @return [Array<PageRegistration>] registered pages in this category
    #
    # @example Creating a category with resources and pages
    #   category = CategoryRegistration.new("Users")
    #   category.resource User, icon: "users", actions: [:index, :show]
    #   category.page :dashboard, label: "Dashboard", controller: "admin/dashboard"
    #
    # @see Registry#register_category
    # @see ResourceRegistration
    # @see PageRegistration
    class CategoryRegistration
      attr_reader :name, :resources, :pages

      # Initialize a new category with an empty set of resources and pages.
      #
      # @param name [String] the category name
      #
      # @example
      #   category = CategoryRegistration.new("Authentication")
      def initialize(name)
        @name = name
        @resources = []
        @pages = []
      end

      # Register a resource (ActiveRecord model) in this category.
      #
      # Resources can be registered with or without a configuration block.
      # When a block is provided, it runs in the context of {ResourceDSLContext}
      # and allows you to define columns, filters, and form fields inline.
      #
      # @param model_class [Class] the ActiveRecord model class to register
      # @param icon [String, nil] optional icon identifier for the resource
      # @param label [String, nil] optional custom label (defaults to humanized plural model name)
      # @param actions [Array<Symbol>] allowed actions for this resource (default: `[:index, :show]`)
      # @param controller [String, nil] optional custom controller path for delegation
      # @param per_page [Integer, nil] number of records per page for index
      # @param default_sort [Hash, nil] default sort configuration (e.g., `{ column: :created_at, direction: :desc }`)
      # @param search_fields [Array<Symbol>, nil] searchable field names
      # @param options [Hash] additional options passed to the registration
      # @yield [ResourceDSLContext] optional block for defining columns, filters, and form fields
      #
      # @return [void]
      #
      # @example Basic resource registration
      #   resource User, icon: "users", actions: [:index, :show]
      #
      # @example Resource with inline DSL
      #   resource User, icon: "users", actions: [:index, :show, :edit, :update] do
      #     column :id, link: true
      #     column :email, sortable: true
      #     filter :email, type: :text
      #     form_field :email, type: :email, required: true
      #   end
      #
      # @example Resource with custom controller
      #   resource Identity, controller: "admin/identities", actions: [:index, :show, :suspend]
      #
      # @see ResourceDSLContext
      # @see ResourceRegistration
      def resource(model_class, icon: nil, label: nil, actions: [:index, :show], controller: nil,
                   per_page: nil, default_sort: nil, search_fields: nil,
                   **options, &block)
        dsl = nil
        if block
          dsl = ResourceDSLContext.new
          dsl.instance_eval(&block)
        end

        @resources << ResourceRegistration.new(
          model_class: model_class,
          category_name: @name,
          icon: icon,
          label: label || model_class.model_name.human.pluralize,
          actions: actions,
          controller: controller,
          columns: dsl&.columns&.presence,
          filters: dsl&.filters&.presence,
          form_fields: dsl&.form_fields&.presence,
          per_page: per_page,
          default_sort: default_sort,
          search_fields: search_fields,
          **options
        )
      end

      # Register a custom page in this category.
      #
      # Pages are non-CRUD admin interfaces that require custom controllers.
      # Unlike resources, pages don't map to a specific model.
      #
      # @param key [Symbol, String] unique identifier for this page
      # @param label [String] the human-readable page name
      # @param icon [String, nil] optional icon identifier
      # @param controller [String] the controller path (e.g., "admin/dashboard")
      # @param actions [Array<Hash>] custom action definitions with `:key`, `:label`, `:method`, `:confirm`
      #
      # @return [PageRegistration] the created page registration
      #
      # @example Basic page
      #   page :dashboard, label: "Dashboard", icon: "home", controller: "admin/dashboard"
      #
      # @example Page with custom actions
      #   page :usage, label: "Usage Reports", controller: "admin/usage",
      #     actions: [
      #       { key: :index, label: "Overview" },
      #       { key: :export, label: "Export CSV", method: :post, confirm: "Export data?" }
      #     ]
      #
      # @see PageRegistration
      def page(key, label:, icon: nil, controller:, actions: [])
        registration = PageRegistration.build(
          key: key,
          label: label,
          icon: icon,
          controller: controller,
          category_name: @name,
          actions: actions
        )
        @pages << registration
        registration
      end

      # Find a resource registration by its model class.
      #
      # @param model_class [Class] the ActiveRecord model class to search for
      #
      # @return [ResourceRegistration, nil] the matching resource registration, or nil if not found
      #
      # @example
      #   category.find_resource(User) #=> ResourceRegistration instance or nil
      def find_resource(model_class)
        @resources.find { |r| r.model_class == model_class }
      end

      # Merge another category's resources and pages into this category.
      #
      # This is used when multiple gems or initializers register resources
      # in the same category. All resources and pages are combined.
      #
      # @param other [CategoryRegistration] the category to merge from
      #
      # @return [void]
      #
      # @example
      #   category1 = CategoryRegistration.new("Auth")
      #   category1.resource User, actions: [:index]
      #
      #   category2 = CategoryRegistration.new("Auth")
      #   category2.resource Session, actions: [:index]
      #
      #   category1.merge(category2)
      #   category1.resources.size #=> 2
      def merge(other)
        @resources.concat(other.resources)
        @pages.concat(other.pages)
      end
    end
  end
end
