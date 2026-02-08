module RSB
  module Admin
    # Represents a registered resource in the admin panel.
    #
    # ResourceRegistration stores metadata about a model that should be accessible
    # in the admin interface, including its category, actions, icon, and optionally
    # a custom controller to handle requests.
    #
    # @example Registering a resource with default generic controller
    #   ResourceRegistration.new(
    #     model_class: User,
    #     category_name: "Users",
    #     icon: "user",
    #     actions: [:index, :show]
    #   )
    #
    # @example Registering a resource with custom controller
    #   ResourceRegistration.new(
    #     model_class: Identity,
    #     category_name: "Authentication",
    #     icon: "users",
    #     actions: [:index, :show, :suspend, :activate],
    #     controller: "rsb/auth/admin/identities"
    #   )
    class ResourceRegistration
      # @return [Class] the ActiveRecord model class this registration represents
      attr_reader :model_class

      # @return [String] the name of the category this resource belongs to
      attr_reader :category_name

      # @return [String, nil] the icon identifier for this resource
      attr_reader :icon

      # @return [String] the human-readable label for this resource
      attr_reader :label

      # @return [Array<Symbol>] the list of allowed actions for this resource
      attr_reader :actions

      # @return [Hash] additional options passed during registration
      attr_reader :options

      # @return [String, nil] the controller path for custom controller (e.g., "rsb/auth/admin/identities")
      attr_reader :controller

      # @return [Array<ColumnDefinition>, nil] column definitions for this resource
      attr_reader :columns

      # @return [Array<FilterDefinition>, nil] filter definitions for this resource
      attr_reader :filters

      # @return [Array<FormFieldDefinition>, nil] form field definitions for this resource
      attr_reader :form_fields

      # @return [Integer, nil] number of records per page
      attr_reader :per_page

      # @return [Hash, nil] default sort configuration (e.g., { column: :created_at, direction: :desc })
      attr_reader :default_sort

      # @return [Array<Symbol>, nil] searchable field names
      attr_reader :search_fields

      # Initialize a new resource registration.
      #
      # @param model_class [Class] the ActiveRecord model class
      # @param category_name [String] the category this resource belongs to
      # @param icon [String, nil] optional icon identifier
      # @param label [String, nil] optional custom label (defaults to humanized plural model name)
      # @param actions [Array<Symbol>] allowed actions (default: [])
      # @param controller [String, nil] optional custom controller path for delegation
      # @param columns [Array<ColumnDefinition>, nil] column definitions
      # @param filters [Array<FilterDefinition>, nil] filter definitions
      # @param form_fields [Array<FormFieldDefinition>, nil] form field definitions
      # @param per_page [Integer, nil] records per page
      # @param default_sort [Hash, nil] default sort configuration
      # @param search_fields [Array<Symbol>, nil] searchable field names
      # @param options [Hash] additional options
      def initialize(model_class:, category_name:, icon: nil, label: nil, actions: [], controller: nil,
                     columns: nil, filters: nil, form_fields: nil,
                     per_page: nil, default_sort: nil, search_fields: nil,
                     **options)
        @model_class = model_class
        @category_name = category_name
        @icon = icon
        @label = label || model_class.model_name.human.pluralize
        @actions = actions.map(&:to_sym)
        @controller = controller
        @columns = columns
        @filters = filters
        @form_fields = form_fields
        @per_page = per_page
        @default_sort = default_sort
        @search_fields = search_fields&.map(&:to_sym)
        @options = options
      end

      # Check if a specific action is allowed for this resource.
      #
      # @param action [Symbol, String] the action to check
      # @return [Boolean] true if the action is in the allowed actions list
      def action?(action)
        @actions.include?(action.to_sym)
      end

      # Check if this resource uses a custom controller.
      #
      # When true, requests to this resource will be delegated to the custom
      # controller instead of being handled by the generic ResourcesController.
      #
      # @return [Boolean] true if a custom controller is configured
      def custom_controller?
        @controller.present?
      end

      # Get the route key for this resource's model.
      #
      # @return [String] the pluralized route key (e.g., "identities" for Identity model)
      def route_key
        model_class.model_name.route_key
      end

      # Returns columns visible on index views.
      #
      # If no columns were explicitly defined via the DSL, this method
      # auto-detects columns from the model's database schema, excluding
      # sensitive columns (passwords, tokens, etc.).
      #
      # @return [Array<ColumnDefinition>] columns to display on index view
      #
      # @example With explicit columns
      #   registration.columns #=> [ColumnDefinition(:id), ColumnDefinition(:email)]
      #   registration.index_columns #=> [ColumnDefinition(:id), ColumnDefinition(:email)]
      #
      # @example With auto-detection
      #   registration.columns #=> nil
      #   registration.index_columns #=> [ColumnDefinition(:id), ColumnDefinition(:email), ...]
      #
      # @see #auto_detect_columns
      def index_columns
        return auto_detect_columns.select { |c| c.visible_on?(:index) } unless columns
        columns.select { |c| c.visible_on?(:index) }
      end

      # Returns columns visible on show (detail) views.
      #
      # If no columns were explicitly defined via the DSL, this method
      # auto-detects columns from the model's database schema, excluding
      # sensitive columns (passwords, tokens, etc.).
      #
      # Show views typically display more columns than index views, including
      # timestamps and metadata fields.
      #
      # @return [Array<ColumnDefinition>] columns to display on show view
      #
      # @see #auto_detect_columns
      def show_columns
        return auto_detect_columns.select { |c| c.visible_on?(:show) } unless columns
        columns.select { |c| c.visible_on?(:show) }
      end

      # Returns form fields for new (create) forms.
      #
      # If no form fields were explicitly defined via the DSL, this method
      # auto-detects editable fields from the model's database schema,
      # excluding sensitive columns, ID, and timestamps.
      #
      # @return [Array<FormFieldDefinition>] form fields for new form
      #
      # @example With explicit form fields
      #   registration.form_fields #=> [FormFieldDefinition(:email), FormFieldDefinition(:name)]
      #   registration.new_form_fields #=> [FormFieldDefinition(:email), FormFieldDefinition(:name)]
      #
      # @example With auto-detection
      #   registration.form_fields #=> nil
      #   registration.new_form_fields #=> [FormFieldDefinition(:email), FormFieldDefinition(:name), ...]
      #
      # @see #auto_detect_form_fields
      def new_form_fields
        return auto_detect_form_fields.select { |f| f.visible_on?(:new) } unless form_fields
        form_fields.select { |f| f.visible_on?(:new) }
      end

      # Returns form fields for edit (update) forms.
      #
      # If no form fields were explicitly defined via the DSL, this method
      # auto-detects editable fields from the model's database schema,
      # excluding sensitive columns, ID, and timestamps.
      #
      # @return [Array<FormFieldDefinition>] form fields for edit form
      #
      # @see #auto_detect_form_fields
      def edit_form_fields
        return auto_detect_form_fields.select { |f| f.visible_on?(:edit) } unless form_fields
        form_fields.select { |f| f.visible_on?(:edit) }
      end

      private

      # Column names that contain sensitive data and should never be displayed.
      #
      # These columns are excluded from auto-detection to prevent accidental
      # exposure of passwords, tokens, and other secrets in the admin interface.
      #
      # @api private
      SENSITIVE_COLUMNS = %w[
        password_digest token encrypted_password
        reset_password_token confirmation_token
        unlock_token otp_secret
      ].freeze

      # Column names that should be excluded from auto-detected form fields.
      #
      # These are typically read-only columns managed by the database or
      # framework (ID, timestamps) that users should not edit directly.
      #
      # @api private
      SKIP_FORM_COLUMNS = %w[
        id created_at updated_at
      ].freeze

      # Column names that should be excluded from index tables.
      #
      # These are typically noisy columns (timestamps, metadata) that clutter
      # table views but are useful in detail views.
      #
      # @api private
      SKIP_INDEX_COLUMNS = %w[
        created_at updated_at metadata
      ].freeze

      # Auto-detect column definitions from the model's database schema.
      #
      # This method introspects the model's columns and creates a
      # {ColumnDefinition} for each non-sensitive column. Used as a fallback
      # when no explicit columns are defined via the DSL.
      #
      # Columns in SKIP_INDEX_COLUMNS are marked as visible only on show views,
      # not index views.
      #
      # @return [Array<ColumnDefinition>] auto-detected column definitions
      # @return [Array] empty array if the model doesn't respond to `column_names`
      #
      # @api private
      def auto_detect_columns
        return [] unless model_class.respond_to?(:column_names)
        model_class.column_names
          .reject { |c| SENSITIVE_COLUMNS.include?(c) }
          .map do |c|
            # Skip index for timestamp/metadata columns
            if SKIP_INDEX_COLUMNS.include?(c)
              ColumnDefinition.build(c.to_sym, visible_on: [:show])
            else
              ColumnDefinition.build(c.to_sym)
            end
          end
      end

      # Auto-detect form field definitions from the model's database schema.
      #
      # This method introspects the model's columns and creates a
      # {FormFieldDefinition} for each editable column. Excludes sensitive
      # columns, ID, and timestamps. Used as a fallback when no explicit
      # form fields are defined via the DSL.
      #
      # @return [Array<FormFieldDefinition>] auto-detected form field definitions
      # @return [Array] empty array if the model doesn't respond to `column_names`
      #
      # @api private
      def auto_detect_form_fields
        return [] unless model_class.respond_to?(:column_names)
        model_class.column_names
          .reject { |c| SENSITIVE_COLUMNS.include?(c) || SKIP_FORM_COLUMNS.include?(c) }
          .map { |c| FormFieldDefinition.build(c.to_sym) }
      end
    end
  end
end
