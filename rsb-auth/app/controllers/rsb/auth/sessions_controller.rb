# frozen_string_literal: true

module RSB
  module Auth
    class SessionsController < ApplicationController
      layout 'rsb/auth/application'

      include RSB::Auth::RateLimitable
      before_action :redirect_if_authenticated, only: :new
      before_action -> { throttle!(key: 'login', limit: 10, period: 60) }, only: :create

      # Renders the login page.
      # - If multiple credential types are enabled, shows the credential selector.
      # - If only one is enabled, shows its form directly.
      # - If ?method= is provided, shows that type's form.
      #
      # @route GET /auth/session/new
      def new
        load_credential_types(:authenticatable)
        resolve_selected_method
        @rsb_page_title = t('rsb.auth.sessions.new.page_title', default: 'Sign In')
        @rsb_meta_description = t('rsb.auth.sessions.new.meta_description', default: 'Sign in to your account')
      end

      # Authenticates the user.
      # Validates the credential_type param is enabled before attempting auth.
      #
      # @route POST /auth/session
      def create
        load_credential_types(:authenticatable)

        # Validate credential_type if provided
        if params[:credential_type].present? && !valid_credential_type?(params[:credential_type], :authenticatable)
          @error = 'This sign-in method is not available.'
          @selected_method = nil
          render :new, status: :unprocessable_entity
          return
        end

        result = RSB::Auth::AuthenticationService.new.call(
          identifier: params[:identifier],
          password: params[:password]
        )

        if result.success?
          session_record = RSB::Auth::SessionService.new.create(
            identity: result.identity,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          cookies.signed[:rsb_session_token] = {
            value: session_record.token,
            httponly: true,
            same_site: :lax
          }
          if result.identity.complete?
            redirect_to main_app.root_path, notice: 'Signed in.'
          else
            redirect_to account_path, alert: 'Please complete your profile.'
          end
        else
          @identifier = params[:identifier]
          @error = result.error
          # Preserve the selected method on error so the form re-renders (not the selector)
          @selected_method = @credential_types.find { |d| d.key.to_s == params[:credential_type].to_s }
          render :new, status: :unprocessable_entity
        end
      end

      def destroy
        current_session&.revoke!
        cookies.delete(:rsb_session_token)
        redirect_to new_session_path, notice: 'Signed out.'
      end

      private

      # Loads enabled credential types filtered by the given capability.
      # Only includes types that have a form_partial (visible in web UI).
      #
      # @param capability [Symbol] :authenticatable or :registerable
      def load_credential_types(capability)
        @credential_types = RSB::Auth.credentials.enabled.select do |defn|
          defn.public_send(capability) && defn.form_partial.present?
        end
      end

      # Resolves @selected_method from ?method= param or auto-selects if only one type.
      def resolve_selected_method
        @selected_method = @credential_types.find { |d| d.key.to_s == params[:method].to_s } if params[:method].present?

        # Auto-select if only one type is enabled
        return unless @selected_method.nil? && @credential_types.size == 1

        @selected_method = @credential_types.first
      end

      # Checks if a credential type key is valid and has the given capability.
      #
      # @param key [String] credential type key
      # @param capability [Symbol] :authenticatable or :registerable
      # @return [Boolean]
      def valid_credential_type?(key, _capability)
        defn = @credential_types.find { |d| d.key.to_s == key.to_s }
        defn.present?
      end
    end
  end
end
