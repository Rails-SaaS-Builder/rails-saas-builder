module RSB
  module Admin
    # View helper methods for internationalization (i18n) in the admin panel.
    #
    # This helper provides scoped translation methods and label resolution
    # with fallback chains for columns, filters, and form fields.
    #
    # The helper is automatically included in all RSB::Admin controllers
    # via the AdminController base class.
    #
    # @example In a view
    #   <%= rsb_admin_t("shared.save") %>
    #   # => "Save"
    #
    # @example Resolving column labels with fallback
    #   <%= rsb_admin_column_label(column, resource_key: "users") %>
    #   # Tries: rsb.admin.resources.users.columns.email
    #   # Falls back to: rsb.admin.columns.email
    #   # Falls back to: column.label
    module I18nHelper
      # Shorthand for admin-scoped i18n lookups.
      #
      # Prefixes the given key with `rsb.admin.` and delegates to Rails' `t()` helper.
      # This keeps view code concise and DRY.
      #
      # @param key [String, Symbol] the i18n key relative to `rsb.admin`
      # @param options [Hash] options to pass to `I18n.t` (e.g., interpolation values)
      #
      # @return [String] the translated string
      #
      # @example Basic usage
      #   rsb_admin_t("shared.save")
      #   # => "Save"
      #
      # @example With interpolation
      #   rsb_admin_t("shared.new", resource: "User")
      #   # => "New User"
      #
      # @example With count for pluralization
      #   rsb_admin_t("shared.showing", from: 1, to: 25, total: 100)
      #   # => "Showing 1-25 of 100"
      def rsb_admin_t(key, **options)
        I18n.t("rsb.admin.#{key}", **options)
      end

      # Resolve a column label through i18n with fallbacks.
      #
      # The label resolution follows a 4-level fallback chain:
      # 1. Per-resource i18n key: `rsb.admin.resources.#{resource_key}.columns.#{column.key}` (if resource_key provided)
      # 2. Global column i18n key: `rsb.admin.columns.#{column.key}`
      # 3. DSL-provided label from ColumnDefinition (column.label)
      # 4. Humanized key (already the default for column.label)
      #
      # This allows per-resource overrides (e.g., "Identity Email" for identities),
      # global column names (e.g., "Email" for all resources), and DSL-level defaults.
      #
      # @param column [ColumnDefinition] the column definition object
      # @param resource_key [String, Symbol, nil] optional resource key for per-resource translations
      #
      # @return [String] the resolved label
      #
      # @example With global i18n
      #   col = ColumnDefinition.build(:email, label: "Fallback")
      #   rsb_admin_column_label(col)
      #   # => "Email" (from rsb.admin.columns.email)
      #
      # @example With per-resource override
      #   rsb_admin_column_label(col, resource_key: "identities")
      #   # => "Identity Email" (from rsb.admin.resources.identities.columns.email)
      #
      # @example Falls back to DSL label
      #   col = ColumnDefinition.build(:custom_field, label: "My Custom Field")
      #   rsb_admin_column_label(col)
      #   # => "My Custom Field" (DSL label, no i18n key exists)
      def rsb_admin_column_label(column, resource_key: nil)
        if resource_key
          result = I18n.t("rsb.admin.resources.#{resource_key}.columns.#{column.key}", default: nil)
          return result if result
        end

        global = I18n.t("rsb.admin.columns.#{column.key}", default: nil)
        return global if global

        column.label
      end

      # Resolve a filter label through i18n with fallbacks.
      #
      # The label resolution follows a fallback chain:
      # 1. Per-resource i18n key: `rsb.admin.resources.#{resource_key}.filters.#{filter.key}` (if resource_key provided)
      # 2. DSL-provided label from FilterDefinition (filter.label)
      #
      # @param filter [FilterDefinition] the filter definition object
      # @param resource_key [String, Symbol, nil] optional resource key for per-resource translations
      #
      # @return [String] the resolved label
      #
      # @example With per-resource i18n
      #   filter = FilterDefinition.build(:status, label: "Fallback")
      #   rsb_admin_filter_label(filter, resource_key: "users")
      #   # => "User Status" (from rsb.admin.resources.users.filters.status)
      #
      # @example Falls back to DSL label
      #   filter = FilterDefinition.build(:custom, label: "Custom Filter")
      #   rsb_admin_filter_label(filter)
      #   # => "Custom Filter" (DSL label, no i18n key exists)
      def rsb_admin_filter_label(filter, resource_key: nil)
        if resource_key
          result = I18n.t("rsb.admin.resources.#{resource_key}.filters.#{filter.key}", default: nil)
          return result if result
        end

        filter.label
      end

      # Resolve a form field label through i18n with fallbacks.
      #
      # The label resolution follows a fallback chain:
      # 1. Per-resource i18n key: `rsb.admin.resources.#{resource_key}.fields.#{field.key}` (if resource_key provided)
      # 2. DSL-provided label from FormFieldDefinition (field.label)
      #
      # @param field [FormFieldDefinition] the form field definition object
      # @param resource_key [String, Symbol, nil] optional resource key for per-resource translations
      #
      # @return [String] the resolved label
      #
      # @example With per-resource i18n
      #   field = FormFieldDefinition.build(:email, label: "Fallback")
      #   rsb_admin_field_label(field, resource_key: "users")
      #   # => "User Email Address" (from rsb.admin.resources.users.fields.email)
      #
      # @example Falls back to DSL label
      #   field = FormFieldDefinition.build(:custom, label: "Custom Field")
      #   rsb_admin_field_label(field)
      #   # => "Custom Field" (DSL label, no i18n key exists)
      def rsb_admin_field_label(field, resource_key: nil)
        if resource_key
          result = I18n.t("rsb.admin.resources.#{resource_key}.fields.#{field.key}", default: nil)
          return result if result
        end

        field.label
      end
    end
  end
end
