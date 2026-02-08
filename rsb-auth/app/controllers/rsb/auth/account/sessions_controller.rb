# frozen_string_literal: true

module RSB
  module Auth
    module Account
      class SessionsController < RSB::Auth::ApplicationController
        before_action :require_authentication

        # Revokes a specific session belonging to the current identity.
        # Scoped to current_identity.sessions to prevent accessing
        # another identity's sessions (raises RecordNotFound).
        #
        # @route DELETE /auth/account/sessions/:id
        def destroy
          target = current_identity.sessions.find(params[:id])
          RSB::Auth::SessionService.new.revoke(target)
          redirect_to account_path, notice: t("rsb.auth.account.session_revoked")
        end

        # Revokes all active sessions for the current identity except
        # the current session. The user remains logged in.
        #
        # @route DELETE /auth/account/sessions
        def destroy_all
          RSB::Auth::SessionService.new.revoke_all(current_identity, except: current_session)
          redirect_to account_path, notice: t("rsb.auth.account.all_sessions_revoked")
        end
      end
    end
  end
end
