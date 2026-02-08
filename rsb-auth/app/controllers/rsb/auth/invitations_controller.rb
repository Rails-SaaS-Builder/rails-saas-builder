module RSB
  module Auth
    class InvitationsController < ApplicationController
      layout "rsb/auth/application"

      def show
        @invitation = RSB::Auth::Invitation.pending.find_by(token: params[:token])
        redirect_to new_session_path, alert: "Invalid or expired invitation." unless @invitation
        @rsb_page_title = t("rsb.auth.invitations.show.page_title", default: "Accept Invitation")
      end

      def update
        result = RSB::Auth::InvitationService.new.accept(
          token: params[:token],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        if result.success?
          redirect_to new_session_path, notice: "Account created. Please sign in."
        else
          @invitation = RSB::Auth::Invitation.find_by(token: params[:token])
          @error = result.error
          render :show, status: :unprocessable_entity
        end
      end
    end
  end
end
