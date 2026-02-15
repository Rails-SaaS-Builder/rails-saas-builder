# frozen_string_literal: true

module RSB
  module Admin
    # DSL context for defining resource columns, filters, and form fields inline.
    #
    # This class provides the block context for the resource registration DSL.
    # It allows you to declaratively define columns, filters, and form fields
    # within a resource registration block.
    #
    # @!attribute [r] columns
    #   @return [Array<ColumnDefinition>] the column definitions added via {#column}
    #
    # @!attribute [r] filters
    #   @return [Array<FilterDefinition>] the filter definitions added via {#filter}
    #
    # @!attribute [r] form_fields
    #   @return [Array<FormFieldDefinition>] the form field definitions added via {#form_field}
    #
    # @example Defining columns, filters, and form fields for a User resource
    #   registry.register_category "Users" do
    #     resource User, icon: "users", actions: [:index, :show] do
    #       column :id, link: true
    #       column :email, sortable: true
    #       column :status, formatter: :badge
    #
    #       filter :email, type: :text
    #       filter :status, type: :select, options: %w[active suspended]
    #
    #       form_field :email, type: :email, required: true
    #       form_field :name, type: :text, required: true
    #     end
    #   end
    #
    # @see CategoryRegistration#resource
    # @see ColumnDefinition
    # @see FilterDefinition
    # @see FormFieldDefinition
    class ResourceDSLContext
      attr_reader :columns, :filters, :form_fields

      # Initialize a new DSL context with empty arrays.
      #
      # @api private
      def initialize
        @columns = []
        @filters = []
        @form_fields = []
      end

      # Define a column to display on index and show pages.
      #
      # Columns control how data is displayed in tables and detail views.
      # Options are passed directly to {ColumnDefinition.build}.
      #
      # @param key [Symbol, String] the attribute name to display
      # @param options [Hash] column configuration options
      # @option options [String] :label the human-readable column header
      # @option options [Boolean] :sortable whether the column can be sorted
      # @option options [Symbol, Proc] :formatter optional formatter for the column value
      # @option options [Boolean] :link whether to render the value as a link
      # @option options [Array<Symbol>] :visible_on contexts where visible (`:index`, `:show`)
      #
      # @return [void]
      #
      # @example Basic column
      #   column :email
      #
      # @example Column with options
      #   column :status, label: "Account Status", sortable: true, formatter: :badge
      #
      # @example Column visible only on show page
      #   column :notes, visible_on: [:show]
      #
      # @see ColumnDefinition.build
      def column(key, **options)
        @columns << ColumnDefinition.build(key, **options)
      end

      # Define a filter for querying records on the index page.
      #
      # Filters allow users to narrow down the displayed records.
      # Options are passed directly to {FilterDefinition.build}.
      #
      # @param key [Symbol, String] the attribute name to filter on
      # @param options [Hash] filter configuration options
      # @option options [String] :label the human-readable filter label
      # @option options [Symbol] :type the filter type (`:text`, `:select`, `:boolean`, `:date_range`, `:number_range`)
      # @option options [Array, Proc] :options options for select-type filters
      # @option options [Symbol, Proc] :scope custom filtering logic
      #
      # @return [void]
      #
      # @example Text filter
      #   filter :email, type: :text
      #
      # @example Select filter with options
      #   filter :status, type: :select, options: %w[active suspended banned]
      #
      # @example Filter with custom scope
      #   filter :search, scope: ->(rel, val) { rel.where("name LIKE ? OR email LIKE ?", "%#{val}%", "%#{val}%") }
      #
      # @see FilterDefinition.build
      def filter(key, **options)
        @filters << FilterDefinition.build(key, **options)
      end

      # Define a form field for new and edit forms.
      #
      # Form fields control how data is entered on create/update forms.
      # Options are passed directly to {FormFieldDefinition.build}.
      #
      # @param key [Symbol, String] the attribute name for this field
      # @param options [Hash] form field configuration options
      # @option options [String] :label the human-readable field label
      # @option options [Symbol] :type the field type (`:text`, `:textarea`, `:select`, `:checkbox`, `:number`, `:email`, `:password`, `:datetime`, `:hidden`, `:json`)
      # @option options [Array, Proc] :options options for select-type fields
      # @option options [Boolean] :required whether the field is required
      # @option options [String] :hint optional help text displayed below the field
      # @option options [Array<Symbol>] :visible_on contexts where visible (`:new`, `:edit`)
      #
      # @return [void]
      #
      # @example Required email field
      #   form_field :email, type: :email, required: true
      #
      # @example Textarea with hint
      #   form_field :bio, type: :textarea, hint: "Tell us about yourself"
      #
      # @example Field visible only on new form
      #   form_field :password, type: :password, required: true, visible_on: [:new]
      #
      # @see FormFieldDefinition.build
      def form_field(key, **options)
        @form_fields << FormFieldDefinition.build(key, **options)
      end
    end
  end
end
