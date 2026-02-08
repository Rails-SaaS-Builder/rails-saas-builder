# frozen_string_literal: true

module RSB
  module Auth
    class AccountController < ApplicationController
      layout "rsb/auth/application"

      include RSB::Auth::RateLimitable
      include RSB::Auth::UserAgentHelper

      before_action :require_authentication
      before_action :check_account_enabled
      before_action :check_deletion_enabled, only: [:confirm_destroy, :destroy]

      # Renders the account hub page with four sections:
      # login methods, identity fields, active sessions, delete account.
      #
      # @route GET /auth/account
      def show
        load_account_data
        @rsb_page_title = t("rsb.auth.account.show.page_title", default: "Account")
      end

      # Updates identity attributes (metadata or concern-provided nested attributes).
      #
      # @route PATCH /auth/account
      def update
        result = RSB::Auth::AccountService.new.update(
          identity: current_identity,
          params: account_params
        )

        if result.success?
          redirect_to account_path, notice: t("rsb.auth.account.updated")
        else
          @errors = result.errors
          load_account_data
          render :show, status: :unprocessable_entity
        end
      end

      # Renders the password confirmation page before account deletion.
      #
      # @route GET /auth/account/confirm_destroy
      def confirm_destroy
      end

      # Soft-deletes the account after password verification.
      # Clears the session cookie and redirects to login.
      #
      # @route DELETE /auth/account
      def destroy
        result = RSB::Auth::AccountService.new.delete_account(
          identity: current_identity,
          password: params[:password],
          current_session: current_session
        )

        if result.success?
          reset_session
          cookies.delete(:rsb_session_token)
          redirect_to new_session_path, notice: t("rsb.auth.account.deleted")
        else
          @errors = result.errors
          render :confirm_destroy, status: :unprocessable_entity
        end
      end

      private

      def account_params
        permitted = RSB::Auth.configuration.permitted_account_params
        permitted = permitted.flat_map { |p| p == :metadata ? [metadata: {}] : [p] }
        params.require(:identity).permit(*permitted)
      rescue ActionController::ParameterMissing
        {}
      end

      def load_account_data
        @identity = current_identity
        @login_methods = current_identity.active_credentials.order(:created_at)
        @sessions = current_identity.sessions.active.order(last_active_at: :desc)
        @current_session = current_session
        @deletion_enabled = RSB::Settings.get("auth.account_deletion_enabled")
      end

      def check_account_enabled
        unless RSB::Settings.get("auth.account_enabled")
          redirect_to main_app.root_path, alert: t("rsb.auth.account.disabled")
        end
      end

      def check_deletion_enabled
        unless RSB::Settings.get("auth.account_deletion_enabled")
          redirect_to account_path, alert: t("rsb.auth.account.deletion_disabled")
        end
      end
    end
  end
end
