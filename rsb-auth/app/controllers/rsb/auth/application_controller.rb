module RSB
  module Auth
    class ApplicationController < ActionController::Base
      helper_method :current_identity, :current_session, :identity_signed_in?

      include RSB::Settings::LocaleHelper
      helper_method :rsb_available_locales, :rsb_current_locale,
                    :rsb_locale_display_name, :rsb_locale_switcher

      include RSB::Settings::SeoHelper
      helper_method :rsb_seo_meta_tags, :rsb_seo_title, :rsb_seo_head_tags, :rsb_seo_body_tags

      before_action :set_seo_context

      private

      def set_seo_context
        @rsb_seo_context = :auth
      end

      def current_session
        @current_session ||= RSB::Auth::SessionService.new.find_by_token(
          cookies.signed[:rsb_session_token]
        )
      end

      def current_identity
        @current_identity ||= current_session&.identity
      end

      def identity_signed_in?
        current_identity.present?
      end

      def require_authentication
        unless identity_signed_in?
          redirect_to new_session_path, alert: "Please sign in."
        end
      end

      def redirect_if_authenticated
        if identity_signed_in?
          redirect_to main_app.root_path
        end
      end
    end
  end
end
