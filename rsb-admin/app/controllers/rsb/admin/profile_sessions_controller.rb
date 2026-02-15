# frozen_string_literal: true

module RSB
  module Admin
    # Handles session revocation from the admin profile page.
    #
    # Like ProfileController, this does NOT perform RBAC authorization —
    # any authenticated admin can manage their own sessions.
    class ProfileSessionsController < AdminController
      # DELETE /admin/profile/sessions/:id
      # Revokes a single session belonging to the current admin user.
      # Cannot revoke the current session (safety check).
      #
      # @return [void]
      def destroy
        admin_session = current_admin_user.admin_sessions.find_by(id: params[:id])

        if admin_session.nil?
          redirect_to rsb_admin.profile_path, alert: I18n.t('rsb.admin.profile.session_not_found')
          return
        end

        if admin_session.current?(session[:rsb_admin_session_token])
          redirect_to rsb_admin.profile_path, alert: I18n.t('rsb.admin.profile.cannot_revoke_current')
          return
        end

        admin_session.destroy
        redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.session_revoked')
      end

      # DELETE /admin/profile/sessions
      # Revokes all sessions except the current one.
      #
      # @return [void]
      def destroy_all
        current_token = session[:rsb_admin_session_token]
        count = current_admin_user.admin_sessions.where.not(session_token: current_token).count
        current_admin_user.admin_sessions.where.not(session_token: current_token).destroy_all

        redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.all_sessions_revoked', count: count)
      end
    end
  end
end
