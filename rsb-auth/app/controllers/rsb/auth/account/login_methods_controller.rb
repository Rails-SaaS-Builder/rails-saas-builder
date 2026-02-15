# frozen_string_literal: true

module RSB
  module Auth
    module Account
      class LoginMethodsController < RSB::Auth::ApplicationController
        layout 'rsb/auth/application'

        include RSB::Auth::RateLimitable

        before_action :require_authentication
        before_action :set_credential
        before_action -> { throttle!(key: 'change_password', limit: 10, period: 60) }, only: :change_password

        # Renders the login method detail page for a specific credential.
        # Shows identifier, type, verification status, change password form,
        # and optional remove button.
        #
        # @route GET /auth/account/login_methods/:id
        def show
          @can_remove = current_identity.active_credentials.count > 1
        end

        # Changes the password on a specific credential.
        # Delegates to AccountService#change_password which verifies the current
        # password and revokes all other sessions on success.
        #
        # @route PATCH /auth/account/login_methods/:id/password
        def change_password
          result = RSB::Auth::AccountService.new.change_password(
            credential: @credential,
            current_password: params[:current_password],
            new_password: params[:new_password],
            new_password_confirmation: params[:new_password_confirmation],
            current_session: current_session
          )

          if result.success?
            redirect_to account_login_method_path(@credential), notice: t('rsb.auth.account.password_changed')
          else
            @password_errors = result.errors
            @can_remove = current_identity.active_credentials.count > 1
            render :show, status: :unprocessable_entity
          end
        end

        # Revokes (removes) a login method.
        # Guards against removing the last active credential.
        #
        # @route DELETE /auth/account/login_methods/:id
        def destroy
          if current_identity.active_credentials.count <= 1
            redirect_to account_path, alert: t('rsb.auth.account.cannot_remove_last')
            return
          end

          @credential.revoke!
          redirect_to account_path, notice: t('rsb.auth.account.login_method_removed')
        end

        # Resends verification email for an unverified credential.
        #
        # @route POST /auth/account/login_methods/:id/resend_verification
        def resend_verification
          if @credential.verified?
            redirect_to account_login_method_path(@credential), alert: t('rsb.auth.account.already_verified')
            return
          end

          RSB::Auth::VerificationService.new.send_verification(@credential)
          redirect_to account_login_method_path(@credential), notice: t('rsb.auth.account.verification_sent')
        end

        private

        # Scoped to current_identity.active_credentials to prevent:
        # - Accessing another identity's credentials (RecordNotFound)
        # - Accessing revoked credentials (not in active scope)
        def set_credential
          @credential = current_identity.active_credentials.find(params[:id])
        end
      end
    end
  end
end
