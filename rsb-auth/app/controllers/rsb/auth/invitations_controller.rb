# frozen_string_literal: true

module RSB
  module Auth
    class InvitationsController < ApplicationController
      layout 'rsb/auth/application'

      # GET /invitations/:token
      # Redirects to registration page with invite_token param.
      # The token is validated by RegistrationService, not here.
      def show
        redirect_to new_registration_path(invite_token: params[:token])
      end
    end
  end
end
