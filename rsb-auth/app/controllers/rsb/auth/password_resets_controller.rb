# frozen_string_literal: true

module RSB
  module Auth
    class PasswordResetsController < ApplicationController
      layout 'rsb/auth/application'

      include RSB::Auth::RateLimitable
      before_action :redirect_if_authenticated, only: :new
      before_action -> { throttle!(key: 'password_reset', limit: 5, period: 60) }, only: :create

      def new
        @rsb_page_title = t('rsb.auth.password_resets.new.page_title', default: 'Forgot Password')
        @rsb_meta_description = t('rsb.auth.password_resets.new.meta_description', default: 'Reset your password')
      end

      def create
        RSB::Auth::PasswordResetService.new.request_reset(params[:identifier])
        redirect_to new_session_path, notice: 'If that identifier exists, a reset link has been sent.'
      end

      def edit
        @token = params[:token]
        reset_token = RSB::Auth::PasswordResetToken.valid.find_by(token: @token)
        redirect_to new_password_reset_path, alert: 'Invalid or expired token.' unless reset_token
        @rsb_page_title = t('rsb.auth.password_resets.edit.page_title', default: 'Reset Password')
      end

      def update
        result = RSB::Auth::PasswordResetService.new.reset_password(
          token: params[:token],
          password: params[:password],
          password_confirmation: params[:password_confirmation]
        )

        if result.success?
          redirect_to new_session_path, notice: 'Password reset. Please sign in.'
        else
          @token = params[:token]
          @error = result.error
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
