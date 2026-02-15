# frozen_string_literal: true

module RSB
  module Admin
    class SettingsController < AdminController
      before_action :authorize_settings

      # GET /admin/settings?tab=auth
      #
      # Renders the settings page with tabbed navigation.
      # Loads settings for the active tab category only.
      # Resolves current values, locked status, and depends_on states
      # for each setting in the active category.
      #
      # @return [void]
      def index
        @rsb_page_title = I18n.t('rsb.admin.settings.page_title', default: 'Settings')
        @categories = RSB::Settings.registry.categories
        @active_tab = resolve_active_tab

        if @active_tab
          @groups = RSB::Settings.registry.grouped_definitions(@active_tab)
          @field_states = build_field_states(@active_tab, @groups)
          @current_values = build_current_values(@active_tab, @groups)
        else
          @groups = {}
          @field_states = {}
          @current_values = {}
        end
      end

      # PATCH /admin/settings
      #
      # Batch update settings for a single category.
      # Receives all field values for the category, diffs against current values,
      # and only persists changed values. Skips locked settings and settings
      # disabled by depends_on.
      #
      # @return [void] redirects to settings page with tab preserved
      def batch_update
        category = params.dig(:settings, :category)
        tab = params.dig(:settings, :tab) || category

        schema = RSB::Settings.registry.for(category)
        unless schema
          redirect_to rsb_admin.settings_path, alert: 'Unknown settings category.'
          return
        end

        submitted = params.dig(:settings, :values)&.to_unsafe_h || {}

        begin
          ActiveRecord::Base.transaction do
            schema.definitions.each do |defn|
              key_str = defn.key.to_s
              next unless submitted.key?(key_str)

              full_key = "#{category}.#{key_str}"

              # Skip locked settings (defense-in-depth)
              next if RSB::Settings.configuration.locked?(full_key)

              # Skip depends_on disabled settings (defense-in-depth)
              if defn.depends_on.present?
                parent_value = RSB::Settings.get(defn.depends_on)
                next unless parent_truthy?(parent_value)
              end

              # Compare with current value (cast submitted string for fair comparison)
              current = RSB::Settings.get(full_key)
              submitted_val = submitted[key_str]

              RSB::Settings.set(full_key, submitted_val) unless values_equal?(current, submitted_val, defn.type)
            end
          end
        rescue RSB::Settings::ValidationError => e
          RSB::Settings.invalidate_cache!
          redirect_to rsb_admin.settings_path(tab: tab), alert: e.message
          return
        end

        redirect_to rsb_admin.settings_path(tab: tab), notice: 'Settings updated successfully.'
      end

      # Existing single-setting update (kept for backward compatibility)
      def update
        key = "#{params[:category]}.#{params[:key]}"

        if RSB::Settings.configuration.locked?(key)
          redirect_to rsb_admin.settings_path, alert: 'Setting is locked.'
          return
        end

        RSB::Settings.set(key, params[:value])
        redirect_to rsb_admin.settings_path, notice: 'Setting updated.'
      end

      private

      # Resolve the active tab from params, falling back to the first category.
      #
      # @return [String, nil] the active category name, or nil if no categories exist
      def resolve_active_tab
        categories = RSB::Settings.registry.categories
        return nil if categories.empty?

        tab = params[:tab]
        categories.include?(tab) ? tab : categories.first
      end

      # Build a hash of setting key -> field state for the active category.
      # States: :editable, :locked, :disabled_by_dependency
      #
      # @param category [String]
      # @param groups [Hash<String, Array<SettingDefinition>>]
      # @return [Hash<Symbol, Symbol>] setting key -> state
      def build_field_states(category, groups)
        states = {}
        locked_keys = RSB::Settings.configuration.locked_keys

        groups.each_value do |definitions|
          definitions.each do |defn|
            full_key = "#{category}.#{defn.key}"

            if locked_keys.include?(full_key)
              states[defn.key] = :locked
            elsif defn.depends_on.present?
              parent_value = RSB::Settings.get(defn.depends_on)
              states[defn.key] = parent_truthy?(parent_value) ? :editable : :disabled_by_dependency
            else
              states[defn.key] = :editable
            end
          end
        end

        states
      end

      # Build a hash of setting key -> current resolved value for the active category.
      #
      # @param category [String]
      # @param groups [Hash<String, Array<SettingDefinition>>]
      # @return [Hash<Symbol, Object>] setting key -> current value
      def build_current_values(category, groups)
        values = {}
        groups.each_value do |definitions|
          definitions.each do |defn|
            values[defn.key] = RSB::Settings.get("#{category}.#{defn.key}")
          end
        end
        values
      end

      # Check if a parent setting value is truthy for depends_on resolution.
      # Falsy: false, nil, 0, "", "false", "0"
      #
      # @param value [Object]
      # @return [Boolean]
      def parent_truthy?(value)
        return false if value.nil?
        return false if value == false
        return false if value == 0 # rubocop:disable Style/NumericPredicate
        return false if value.is_a?(String) && value.blank?
        return false if value.to_s.downcase == 'false'
        return false if value.to_s == '0'

        true
      end

      # Compare current value to submitted value with type-appropriate casting.
      # Submitted values come as strings from HTML forms.
      #
      # @param current [Object] the current resolved value
      # @param submitted [String] the submitted form value
      # @param type [Symbol] the setting type
      # @return [Boolean] true if values are equal
      def values_equal?(current, submitted, type)
        case type
        when :boolean
          current_bool = ActiveModel::Type::Boolean.new.cast(current)
          submitted_bool = ActiveModel::Type::Boolean.new.cast(submitted)
          current_bool == submitted_bool
        when :integer
          current.to_i == submitted.to_i
        when :float
          current.to_f == submitted.to_f
        else
          current.to_s == submitted.to_s
        end
      end

      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t('rsb.admin.shared.system'))
        add_breadcrumb(I18n.t('rsb.admin.settings.title'))
      end

      def authorize_settings
        authorize_admin_action!(resource: 'settings', action: action_name)
      end
    end
  end
end
