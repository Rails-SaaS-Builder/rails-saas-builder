# frozen_string_literal: true

module RSB
  module Auth
    # Opt-in concern for host app controllers that redirects users with
    # incomplete identities to the account edit page.
    #
    # Include in your ApplicationController to enforce profile completion:
    #
    # @example
    #   class ApplicationController < ActionController::Base
    #     include RSB::Auth::EnsureIdentityComplete
    #   end
    #
    # The concern adds a +before_action+ that checks +current_identity.complete?+
    # (from RFC-010). If the identity is incomplete, the user is redirected to
    # +/auth/account+ with a flash message.
    #
    # Auth engine routes are skipped to prevent redirect loops (e.g., the account
    # page itself, login, registration).
    #
    module EnsureIdentityComplete
      extend ActiveSupport::Concern

      included do
        before_action :ensure_identity_complete
      end

      private

      # Redirects to account edit if the current identity exists but is incomplete.
      # Skips check for auth engine routes to prevent redirect loops.
      #
      # @return [void]
      def ensure_identity_complete
        identity = current_identity_for_completion_check
        return unless identity
        return if identity.complete?
        return if rsb_auth_engine_route?

        redirect_to RSB::Auth::Engine.routes.url_helpers.account_path,
                    alert: t("rsb.auth.account.complete_profile")
      end

      # Resolves the current identity from the session cookie so the concern
      # works in the host app without requiring the host to define +current_identity+.
      #
      # @return [RSB::Auth::Identity, nil]
      def current_identity_for_completion_check
        session = RSB::Auth::SessionService.new.find_by_token(
          cookies.signed[:rsb_session_token]
        )
        session&.identity
      end

      # Checks whether the current request is handled by the rsb-auth engine.
      # Used to skip the completion check on auth routes (login, registration,
      # account edit) to prevent redirect loops.
      #
      # @return [Boolean]
      def rsb_auth_engine_route?
        script_name = RSB::Auth::Engine.routes.find_script_name({})
        return self.class.module_parents.include?(RSB::Auth) if script_name.nil? || script_name.empty?

        request.path.start_with?(script_name)
      rescue StandardError
        # Fallback: check if controller is under RSB::Auth namespace
        self.class.module_parents.include?(RSB::Auth)
      end
    end
  end
end
