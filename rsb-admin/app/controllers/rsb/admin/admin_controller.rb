# frozen_string_literal: true

module RSB
  module Admin
    class AdminController < ActionController::Base
      layout -> { RSB::Admin.configuration.layout }

      include Authorization

      helper RSB::Admin::IconsHelper
      helper RSB::Admin::ThemeHelper
      helper RSB::Admin::FormattingHelper
      helper RSB::Admin::I18nHelper
      helper RSB::Admin::TableHelper
      helper RSB::Admin::AuthorizationHelper
      helper RSB::Admin::BrandingHelper
      helper RSB::Admin::UrlHelper
      include RSB::Admin::UrlHelper
      helper RSB::Settings::LocaleHelper
      include RSB::Settings::LocaleHelper
      helper RSB::Settings::SeoHelper
      include RSB::Settings::SeoHelper

      before_action :set_seo_context
      before_action :check_admin_enabled
      before_action :require_admin_authentication
      before_action :enforce_two_factor_enrollment
      before_action :build_breadcrumbs
      before_action :track_session_activity

      helper_method :current_admin_user, :admin_registry, :breadcrumbs, :current_admin_session

      private

      def set_seo_context
        @rsb_seo_context = :admin
      end

      def check_admin_enabled
        return if RSB::Admin.enabled?

        render template: 'rsb/admin/shared/disabled', layout: false, status: :service_unavailable
      end

      def require_admin_authentication
        return if current_admin_user

        redirect_to rsb_admin.login_path, alert: 'Please sign in.'
      end

      def enforce_two_factor_enrollment
        return unless current_admin_user
        return unless ActiveModel::Type::Boolean.new.cast(RSB::Settings.get('admin.require_two_factor'))
        return if current_admin_user.otp_enabled?

        # Allow access to TwoFactorController and logout
        return if is_a?(RSB::Admin::TwoFactorController)
        return if controller_name == 'sessions' && action_name == 'destroy'

        redirect_to rsb_admin.new_profile_two_factor_path,
                    alert: 'Two-factor authentication is required. Please set up 2FA to continue.'
      end

      def current_admin_user
        return @current_admin_user if defined?(@current_admin_user)

        token = session[:rsb_admin_session_token]
        @current_admin_session = token ? AdminSession.find_by(session_token: token) : nil
        @current_admin_user = @current_admin_session&.admin_user
      end

      # Returns the current admin session record for this request.
      # Must call current_admin_user first to populate.
      #
      # @return [AdminSession, nil]
      def current_admin_session
        current_admin_user unless defined?(@current_admin_session)
        @current_admin_session
      end

      # Touches the current session's last_active_at timestamp.
      # Runs on every authenticated request. Uses update_column
      # to avoid callbacks/timestamps overhead.
      #
      # @return [void]
      def track_session_activity
        current_admin_session&.touch_activity!
      end

      def admin_registry
        RSB::Admin.registry
      end

      def breadcrumbs
        @breadcrumbs || []
      end

      # Builds the initial breadcrumb trail with the app name as root.
      # The root item links to the dashboard path as the home destination.
      # Subclasses call super and then add their own items via add_breadcrumb.
      #
      # If breadcrumbs were passed via request.env (from Rack dispatch),
      # those are used instead of building from scratch.
      #
      # @return [void]
      def build_breadcrumbs
        if request.env['rsb.admin.breadcrumbs']
          @breadcrumbs = request.env['rsb.admin.breadcrumbs'].dup
          return
        end

        @breadcrumbs = [
          RSB::Admin::BreadcrumbItem.new(
            label: RSB::Settings.get('admin.app_name').to_s.presence || RSB::Admin.configuration.app_name,
            path: rsb_admin.dashboard_path
          )
        ]
      end

      # Appends a breadcrumb item to the current trail.
      #
      # @param label [String] the text to display
      # @param path [String, nil] the URL path (nil for current/last item)
      # @return [void]
      def add_breadcrumb(label, path = nil)
        @breadcrumbs << RSB::Admin::BreadcrumbItem.new(label: label, path: path)
      end

      # Replaces the entire breadcrumb trail.
      #
      # @param items [Array<RSB::Admin::BreadcrumbItem>] the new breadcrumb items
      # @return [void]
      def set_breadcrumbs(items)
        @breadcrumbs = items
      end
    end
  end
end
