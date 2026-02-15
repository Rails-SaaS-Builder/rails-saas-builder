# frozen_string_literal: true

module RSB
  module Admin
    class SessionsController < ActionController::Base
      layout 'rsb/admin/application'

      helper RSB::Admin::BrandingHelper
      helper RSB::Settings::LocaleHelper
      include RSB::Settings::LocaleHelper
      helper RSB::Settings::SeoHelper
      include RSB::Settings::SeoHelper
      helper_method :current_admin_user

      before_action :set_seo_context
      before_action :check_admin_enabled
      before_action :redirect_if_signed_in, only: [:new]

      def new
        @rsb_page_title = I18n.t('rsb.admin.sessions.new.page_title', default: 'Admin Sign In')
      end

      def create
        admin = AdminUser.find_by(email: params[:email])
        if admin&.authenticate(params[:password])
          if admin.otp_enabled?
            # Store pending state — admin must complete 2FA
            session[:rsb_admin_pending_user_id] = admin.id
            session[:rsb_admin_pending_at] = Time.current.to_i
            session[:rsb_admin_2fa_attempts] = 0
            redirect_to rsb_admin.two_factor_login_path
          elsif ActiveModel::Type::Boolean.new.cast(RSB::Settings.get('admin.require_two_factor'))
            # Check if force 2FA is enabled
            admin_session = AdminSession.create_from_request!(admin_user: admin, request: request)
            session[:rsb_admin_session_token] = admin_session.session_token
            admin.record_sign_in!(ip: request.remote_ip)
            redirect_to rsb_admin.new_profile_two_factor_path,
                        alert: 'Two-factor authentication is required. Please set up 2FA to continue.'
          # Create session but redirect to enrollment
          else
            complete_sign_in!(admin)
          end
        else
          @email = params[:email]
          flash.now[:alert] = 'Invalid email or password.'
          render :new, status: :unprocessable_entity
        end
      end

      def two_factor
        return if valid_pending_session?

        redirect_to rsb_admin.login_path, alert: pending_expired? ? 'Session expired. Please sign in again.' : nil
        nil
      end

      def verify_two_factor
        unless valid_pending_session?
          redirect_to rsb_admin.login_path, alert: pending_expired? ? 'Session expired. Please sign in again.' : nil
          return
        end

        if session[:rsb_admin_2fa_attempts].to_i >= 5
          clear_pending_session!
          redirect_to rsb_admin.login_path, alert: 'Too many attempts. Please sign in again.'
          return
        end

        admin = AdminUser.find_by(id: session[:rsb_admin_pending_user_id])
        unless admin
          clear_pending_session!
          redirect_to rsb_admin.login_path
          return
        end

        if admin.verify_otp(params[:otp_code]) || admin.verify_backup_code(params[:otp_code].to_s)
          clear_pending_session!
          complete_sign_in!(admin)
        else
          session[:rsb_admin_2fa_attempts] = session[:rsb_admin_2fa_attempts].to_i + 1
          flash.now[:alert] = 'Invalid verification code.'
          render :two_factor, status: :unprocessable_entity
        end
      end

      def destroy
        token = session[:rsb_admin_session_token]
        AdminSession.find_by(session_token: token)&.destroy if token
        session.delete(:rsb_admin_session_token)
        redirect_to rsb_admin.login_path, notice: 'Signed out.'
      end

      private

      def set_seo_context
        @rsb_seo_context = :admin
      end

      def complete_sign_in!(admin)
        admin_session = AdminSession.create_from_request!(admin_user: admin, request: request)
        session[:rsb_admin_session_token] = admin_session.session_token
        admin.record_sign_in!(ip: request.remote_ip)
        redirect_to rsb_admin.dashboard_path, notice: 'Signed in successfully.'
      end

      def valid_pending_session?
        session[:rsb_admin_pending_user_id].present? && !pending_expired?
      end

      def pending_expired?
        pending_at = session[:rsb_admin_pending_at].to_i
        pending_at.positive? && Time.at(pending_at) < 5.minutes.ago
      end

      def clear_pending_session!
        session.delete(:rsb_admin_pending_user_id)
        session.delete(:rsb_admin_pending_at)
        session.delete(:rsb_admin_2fa_attempts)
      end

      def check_admin_enabled
        return if RSB::Admin.enabled?

        render template: 'rsb/admin/shared/disabled', layout: false, status: :service_unavailable
      end

      def redirect_if_signed_in
        redirect_to rsb_admin.dashboard_path if current_admin_user
      end

      def current_admin_user
        return @current_admin_user if defined?(@current_admin_user)

        token = session[:rsb_admin_session_token]
        @current_admin_user = token ? AdminSession.find_by(session_token: token)&.admin_user : nil
      end
    end
  end
end
