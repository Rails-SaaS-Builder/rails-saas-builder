# frozen_string_literal: true

module RSB
  module Auth
    class VerificationsController < ApplicationController
      layout 'rsb/auth/application'

      def show
        @rsb_page_title = t('rsb.auth.verifications.show.page_title', default: 'Verify Email')
        result = RSB::Auth::VerificationService.new.verify(params[:token])
        if result.success?
          redirect_to new_session_path, notice: 'Email verified. Please sign in.'
        else
          redirect_to new_session_path, alert: result.error
        end
      end

      def create
        credential = current_identity&.primary_credential
        if credential && !credential.verified?
          RSB::Auth::VerificationService.new.send_verification(credential)
          redirect_back fallback_location: main_app.root_path, notice: 'Verification email sent.'
        else
          redirect_back fallback_location: main_app.root_path, alert: 'Unable to send verification.'
        end
      end
    end
  end
end
