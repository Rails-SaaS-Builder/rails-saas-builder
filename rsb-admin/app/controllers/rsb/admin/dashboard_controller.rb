# frozen_string_literal: true

module RSB
  module Admin
    class DashboardController < AdminController
      before_action :authorize_dashboard, only: :index

      def index
        @rsb_page_title = I18n.t('rsb.admin.dashboard.page_title', default: 'Dashboard')
        dashboard_page = RSB::Admin.registry.dashboard_page

        return unless dashboard_page

        dispatch_to_dashboard(dashboard_page, :index)
      end

      def dashboard_action
        dashboard_page = RSB::Admin.registry.dashboard_page

        unless dashboard_page
          head :not_found
          return
        end

        action_key = params[:action_key]
        action = dashboard_page.find_action(action_key)

        unless action
          head :not_found
          return
        end

        authorize_admin_action!(resource: 'dashboard', action: action_key)
        return if performed?

        request.env['rsb.admin.breadcrumbs'] = @breadcrumbs
        dispatch_to_dashboard(dashboard_page, action_key.to_sym)
      end

      private

      # Builds breadcrumbs for the dashboard page.
      # Admin > Dashboard
      #
      # @return [void]
      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t('rsb.admin.dashboard.title'))
      end

      def authorize_dashboard
        authorize_admin_action!(resource: 'dashboard', action: 'index')
      end

      # Dispatch to a custom dashboard controller via Rack interface.
      #
      # Uses the same Rack dispatch pattern as ResourcesController for pages.
      # Passes breadcrumbs via request.env and copies the response (status,
      # headers, body) back to the current controller.
      #
      # @param dashboard_page [PageRegistration] the dashboard page registration
      # @param action [Symbol] the action to invoke on the custom controller
      # @return [void]
      def dispatch_to_dashboard(dashboard_page, action)
        request.env['rsb.admin.breadcrumbs'] = @breadcrumbs
        controller_name = dashboard_page.controller
        controller_class_name = "#{controller_name}_controller".classify
        controller_class = controller_class_name.constantize
        status, headers, body = controller_class.action(action).call(request.env)
        self.status = status
        self.response_body = body
        headers.each { |k, v| response.headers[k] = v }
      end
    end
  end
end
