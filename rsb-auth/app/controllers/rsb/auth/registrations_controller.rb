# frozen_string_literal: true

module RSB
  module Auth
    class RegistrationsController < ApplicationController
      layout 'rsb/auth/application'

      include RSB::Auth::RateLimitable
      before_action :redirect_if_authenticated, only: :new
      before_action :check_registration_mode
      before_action -> { throttle!(key: 'register', limit: 5, period: 60) }, only: :create

      # Renders the signup page with credential selector.
      #
      # @route GET /auth/registration/new
      def new
        load_credential_types(:registerable)
        resolve_selected_method
        @rsb_page_title = t('rsb.auth.registrations.new.page_title', default: 'Create Account')
        @rsb_meta_description = t('rsb.auth.registrations.new.meta_description', default: 'Create a new account')
      end

      # Creates a new account.
      # Validates credential_type param and passes it to RegistrationService.
      #
      # @route POST /auth/registration
      def create
        load_credential_types(:registerable)

        # Validate credential_type if provided
        if params[:credential_type].present? && !valid_credential_type?(params[:credential_type], :registerable)
          @errors = ['This registration method is not available.']
          @selected_method = nil
          render :new, status: :unprocessable_entity
          return
        end

        result = RSB::Auth::RegistrationService.new.call(
          identifier: params[:identifier],
          password: params[:password],
          password_confirmation: params[:password_confirmation],
          credential_type: params[:credential_type]&.to_sym,
          recovery_email: params[:recovery_email]
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
            redirect_to main_app.root_path, notice: 'Account created.'
          else
            redirect_to account_path, alert: 'Please complete your profile.'
          end
        else
          @identifier = params[:identifier]
          @errors = result.errors
          @selected_method = @credential_types.find { |d| d.key.to_s == params[:credential_type].to_s }
          render :new, status: :unprocessable_entity
        end
      end

      private

      def check_registration_mode
        mode = RSB::Settings.get('auth.registration_mode')
        if mode.to_s == 'disabled'
          redirect_to new_session_path, alert: 'Registration is disabled.'
        elsif mode.to_s == 'invite_only'
          redirect_to new_session_path, alert: 'Registration is invite-only. You need an invitation.'
        end
      end

      def load_credential_types(capability)
        @credential_types = RSB::Auth.credentials.enabled.select do |defn|
          defn.public_send(capability) && defn.form_partial.present? &&
            ActiveModel::Type::Boolean.new.cast(
              RSB::Settings.get("auth.credentials.#{defn.key}.registerable")
            )
        end
      end

      def resolve_selected_method
        @selected_method = @credential_types.find { |d| d.key.to_s == params[:method].to_s } if params[:method].present?

        return unless @selected_method.nil? && @credential_types.size == 1

        @selected_method = @credential_types.first
      end

      def valid_credential_type?(key, _capability)
        defn = @credential_types.find { |d| d.key.to_s == key.to_s }
        defn.present?
      end
    end
  end
end
