# frozen_string_literal: true

module RSB
  module Admin
    class ResourcesController < AdminController
      prepend_before_action :resolve_registry_entry
      before_action :authorize_resource

      # Display the index page for a resource or page.
      #
      # Behavior depends on the type of entry:
      # - If it's a page, delegates to the page's controller
      # - If it's a resource with a custom controller, delegates to that controller
      # - Otherwise, loads records with filtering, sorting, and pagination
      #
      # Filtering is applied from params[:q] using registered FilterDefinitions.
      # Sorting is applied from params[:sort] and params[:dir], with fallback to default_sort.
      # Pagination uses per_page from registration or global config, with 1-based page numbers.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the index action
      def index
        if @page
          dispatch_to_page_controller(:index)
          return
        end

        return dispatch_to_custom_controller(:index) if @registration&.custom_controller?

        authorize_resource

        scope = @registration.model_class.all

        # Apply filters (rule #3: only if registration has filters)
        if @registration.filters&.any? && params[:q].present?
          @registration.filters.each do |filter|
            value = params[:q][filter.key.to_s]
            scope = filter.apply(scope, value)
          end
        end

        # Apply sorting (rule #11)
        sort_column = params[:sort]
        sort_direction = params[:dir]&.downcase == 'desc' ? 'DESC' : 'ASC'

        scope = if sort_column.present? && @registration.columns&.any? { |c| c.key.to_s == sort_column && c.sortable }
                  scope.order(Arel.sql("#{sort_column} #{sort_direction}"))
                elsif @registration.default_sort
                  scope.order(@registration.default_sort[:column] => @registration.default_sort[:direction])
                else
                  scope.order(id: :desc)
                end

        # Pagination (rule #10)
        per_page = @registration.per_page || RSB::Admin.configuration.per_page
        @current_page = [params[:page].to_i, 1].max
        @total_count = scope.count
        @total_pages = (@total_count.to_f / per_page).ceil
        @total_pages = 1 if @total_pages < 1
        @records = scope.limit(per_page).offset((@current_page - 1) * per_page)

        # Store filter values for view
        @filter_values = params[:q] || {}

        # Set page title
        @rsb_page_title = @registration.label
      end

      # Display the show page for a specific resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, loads the record and renders the generic show view.
      # The view uses @registration.show_columns to determine which fields to display.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the show action
      # @raise [ActiveRecord::RecordNotFound] if the record doesn't exist
      def show
        return dispatch_to_custom_controller(:show) if @registration&.custom_controller?

        authorize_resource
        @record = @registration.model_class.find(params[:id])
        @rsb_page_title = "#{@registration.label.singularize} ##{@record.id}"
      end

      # Display the new page for creating a resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, instantiates a new record and renders the generic new view.
      # The view uses @registration.new_form_fields to determine which fields to display.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the new action
      def new
        return dispatch_to_custom_controller(:new) if @registration&.custom_controller?

        authorize_resource
        @record = @registration.model_class.new
      end

      # Create a new resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, creates a new record with the submitted params and either
      # redirects to the show page on success or re-renders the form on failure.
      # Flash message is localized using i18n key "rsb.admin.resources.created".
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the create action
      def create
        return dispatch_to_custom_controller(:create) if @registration&.custom_controller?

        authorize_resource
        @record = @registration.model_class.new(resource_params)
        if @record.save
          redirect_to rsb_admin_resource_show_path(@registration.route_key, @record.id),
                      notice: I18n.t('rsb.admin.resources.created', resource: @registration.label.singularize)
        else
          render :new, status: :unprocessable_entity
        end
      end

      # Display the edit page for a resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, loads the record and renders the generic edit view.
      # The view uses @registration.edit_form_fields to determine which fields to display.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the edit action
      # @raise [ActiveRecord::RecordNotFound] if the record doesn't exist
      def edit
        return dispatch_to_custom_controller(:edit) if @registration&.custom_controller?

        authorize_resource
        @record = @registration.model_class.find(params[:id])
      end

      # Update a resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, updates the record with the submitted params and either
      # redirects to the show page on success or re-renders the edit form on failure.
      # Flash message is localized using i18n key "rsb.admin.resources.updated".
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the update action
      # @raise [ActiveRecord::RecordNotFound] if the record doesn't exist
      def update
        return dispatch_to_custom_controller(:update) if @registration&.custom_controller?

        authorize_resource
        @record = @registration.model_class.find(params[:id])
        if @record.update(resource_params)
          redirect_to rsb_admin_resource_show_path(@registration.route_key, @record.id),
                      notice: I18n.t('rsb.admin.resources.updated', resource: @registration.label.singularize)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # Delete a resource record.
      #
      # If the resource has a custom controller, delegates to it.
      # Otherwise, destroys the record and redirects to the index.
      # Flash message is localized using i18n key "rsb.admin.resources.deleted".
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the resource doesn't support the destroy action
      # @raise [ActiveRecord::RecordNotFound] if the record doesn't exist
      def destroy
        if @page
          dispatch_to_page_controller(:destroy)
        elsif @registration&.custom_controller?
          dispatch_to_custom_controller(:destroy)
        elsif @registration
          authorize_resource
          @record = @registration.model_class.find(params[:id])
          @record.destroy!
          redirect_to rsb_admin_resource_path(@registration.route_key),
                      notice: I18n.t('rsb.admin.resources.deleted', resource: @registration.label.singularize)
        end
      end

      # Generic fallback for pages without a controller.
      #
      # @return [void]
      def page
        # Renders the generic page view
      end

      # Handle static page sub-actions.
      #
      # Routes like `/admin/dashboard/export` are dispatched to the page's
      # controller with the action key. Returns 404 if the page or action
      # is not found.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if the page or action doesn't exist
      def page_action
        @page = RSB::Admin.registry.find_page_by_key(params[:resource_key])

        unless @page
          head :not_found
          return
        end

        authorize_admin_action!(resource: @page.key.to_s, action: params[:action_key])

        action = @page.find_action(params[:action_key])
        unless action
          head :not_found
          return
        end

        # Build page breadcrumbs and pass to dispatched controller
        build_page_action_breadcrumbs
        request.env['rsb.admin.breadcrumbs'] = @breadcrumbs

        # Dispatch to the page's controller with the action key
        controller_name = @page.controller
        controller_class_name = "#{controller_name}_controller".classify
        controller_class = controller_class_name.constantize
        dispatch_action = params[:action_key].to_sym

        status, headers, body = controller_class.action(dispatch_action).call(request.env)
        self.status = status
        self.response_body = body
        headers.each { |k, v| response.headers[k] = v }
      end

      # Handle custom member actions for resources with custom controllers.
      #
      # Custom actions are PATCH routes like `/admin/identities/:id/suspend`.
      # The action name is extracted from params and delegated to the resource's
      # custom controller if it exists and the action is registered.
      #
      # @return [void]
      # @raise [ActionController::RoutingError] if no custom controller is configured
      #   or the action is not registered for this resource
      def custom_action
        action = params[:custom_action].to_sym
        unless @registration&.custom_controller? && @registration.action?(action)
          raise ActionController::RoutingError, 'Not Found'
        end

        dispatch_to_custom_controller(action)
      end

      private

      # Builds breadcrumbs for dynamic resource and page routes.
      #
      # For resources: AppName > Category > Resource Label > #ID (if show/edit) > New/Edit
      # For pages: AppName > Category > Page Label
      #
      # Uses prepend_before_action :resolve_registry_entry to ensure @registration
      # and @page are set before this runs (ahead of inherited AdminController callbacks).
      #
      # @return [void]
      def build_breadcrumbs
        super
        if @registration
          add_breadcrumb(@registration.category_name)
          add_breadcrumb(@registration.label, rsb_admin_resource_path(@registration.route_key))
          if params[:id].present?
            add_breadcrumb("##{params[:id]}",
                           rsb_admin_resource_show_path(@registration.route_key, params[:id]))
          end
          if action_name.in?(%w[new create])
            add_breadcrumb(I18n.t('rsb.admin.shared.new', resource: @registration.label.singularize))
          end
          add_breadcrumb(I18n.t('rsb.admin.shared.edit')) if action_name.in?(%w[edit update])
        elsif @page
          add_breadcrumb(@page.category_name)
          add_breadcrumb(@page.label)
        end
      end

      # Builds breadcrumbs for page sub-actions dispatched via page_action.
      #
      # Since page_action bypasses the normal build_breadcrumbs flow (it's a
      # separate action on ResourcesController), we manually construct the
      # breadcrumb trail: Root > Category > Page Label
      #
      # The page label includes a path since sub-actions may append additional
      # breadcrumb items after it.
      #
      # @return [void]
      def build_page_action_breadcrumbs
        @breadcrumbs = [
          RSB::Admin::BreadcrumbItem.new(
            label: RSB::Settings.get('admin.app_name').to_s.presence || RSB::Admin.configuration.app_name,
            path: rsb_admin.dashboard_path
          )
        ]
        add_breadcrumb(@page.category_name)
        add_breadcrumb(@page.label, rsb_admin_page_path(@page.key))
      end

      def resolve_registry_entry
        @registration = RSB::Admin.registry.find_resource_by_route_key(params[:resource_key])

        return if @registration

        @page = RSB::Admin.registry.find_page_by_key(params[:resource_key])
        raise ActionController::RoutingError, 'Not Found' unless @page
      end

      def authorize_resource
        resource_name = @page ? @page.key.to_s : params[:resource_key]
        action = if action_name == 'custom_action' && params[:custom_action].present?
                   params[:custom_action]
                 else
                   action_name
                 end
        authorize_admin_action!(resource: resource_name, action: action)
      end

      # Dispatch a request to a page's custom controller.
      #
      # Uses the Rack interface to invoke the controller action and copy the
      # response (status, headers, body) into the current controller's response.
      # Falls back to rendering the generic page view if the controller doesn't exist.
      #
      # @param action [Symbol] the action to invoke (default: :index)
      # @return [void]
      def dispatch_to_page_controller(action = :index)
        controller_name = @page.controller
        controller_class_name = "#{controller_name}_controller".classify

        begin
          controller_class = controller_class_name.constantize
          # Pass breadcrumb context to the dispatched controller
          request.env['rsb.admin.breadcrumbs'] = @breadcrumbs
          status, headers, body = controller_class.action(action).call(request.env)
          self.status = status
          self.response_body = body
          headers.each { |k, v| response.headers[k] = v }
        rescue NameError
          # Controller class doesn't exist, render generic fallback
          render :page
        end
      end

      # Dispatch a request to a resource's custom controller.
      #
      # Uses the Rack interface to invoke the controller action and copy the
      # response (status, headers, body) into the current controller's response.
      # This allows resources to have dedicated controllers while maintaining
      # a single routing structure.
      #
      # @param action [Symbol] the action to invoke
      # @return [void]
      # @raise [NameError] if the controller class doesn't exist
      def dispatch_to_custom_controller(action)
        controller_name = @registration.controller
        controller_class_name = "#{controller_name}_controller".classify
        controller_class = controller_class_name.constantize
        # Pass breadcrumb context to the dispatched controller
        request.env['rsb.admin.breadcrumbs'] = @breadcrumbs
        status, headers, body = controller_class.action(action).call(request.env)
        self.status = status
        self.response_body = body
        headers.each { |k, v| response.headers[k] = v }
      end

      # Extract permitted params for the resource model.
      #
      # Uses form_fields from registration when available, otherwise auto-detects
      # editable columns from the model's schema (excluding sensitive columns,
      # ID, and timestamps).
      #
      # @return [ActionController::Parameters] the permitted parameters
      def resource_params
        if @registration.form_fields
          permitted_keys = @registration.form_fields.map(&:key)
        else
          # Fallback: auto-detect (existing behavior)
          permitted_keys = @registration.model_class.column_names - ResourceRegistration::SENSITIVE_COLUMNS - ResourceRegistration::SKIP_FORM_COLUMNS
        end
        params.require(@registration.model_class.model_name.param_key).permit(*permitted_keys)
      end
    end
  end
end
