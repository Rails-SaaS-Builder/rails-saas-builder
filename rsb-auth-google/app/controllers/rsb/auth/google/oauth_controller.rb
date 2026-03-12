# frozen_string_literal: true

module RSB
  module Auth
    module Google
      # Handles Google OAuth redirect and callback.
      # Mounted at /auth/oauth/google (configured in routes).
      #
      # Actions:
      #   GET /  (redirect) -- Generates state/nonce, redirects to Google consent screen
      #   GET /callback     -- Validates state, exchanges code, creates/links credential
      class OauthController < RSB::Auth::ApplicationController
        GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'

        include RSB::Auth::RateLimitable

        skip_before_action :verify_authenticity_token, only: :callback
        before_action -> { throttle!(key: 'google_oauth_redirect', limit: 30, period: 60) }, only: :redirect
        before_action -> { throttle!(key: 'google_oauth_callback', limit: 20, period: 60) }, only: :callback

        # Initiates the Google OAuth flow.
        # Generates CSRF state + nonce, stores in session, and redirects
        # the user to Google's OAuth consent screen.
        #
        # @route GET /auth/oauth/google
        def redirect
          unless google_enabled?
            redirect_to main_app_login_path, alert: 'This sign-in method is not available.'
            return
          end

          unless google_configured?
            Rails.logger.error { "#{LOG_TAG} Google OAuth not configured: missing client_id or client_secret" }
            redirect_to main_app_login_path, alert: 'Google authentication is not configured.'
            return
          end

          mode = params[:mode].presence || 'login'
          if mode == 'link' && !current_identity
            redirect_to rsb_auth.new_session_path
            return
          end

          state = SecureRandom.urlsafe_base64(32)
          nonce = SecureRandom.urlsafe_base64(32)
          session[:google_oauth_state] = state
          session[:google_oauth_nonce] = nonce
          session[:google_oauth_mode] = mode

          Rails.logger.info { "#{LOG_TAG} Initiating Google OAuth for mode=#{mode}" }

          auth_params = {
            client_id: RSB::Settings.get('auth.credentials.google.client_id'),
            redirect_uri: google_callback_url,
            response_type: 'code',
            scope: 'openid email',
            state: state,
            nonce: nonce
          }

          login_hint = sanitize_login_hint(params[:login_hint])
          auth_params[:login_hint] = login_hint if login_hint.present?

          redirect_to "#{GOOGLE_AUTH_URL}?#{auth_params.to_query}", allow_other_host: true
        end

        # Processes the Google OAuth callback.
        # Validates state, exchanges authorization code for tokens,
        # verifies id_token, and delegates to CallbackService.
        #
        # @route GET /auth/oauth/google/callback
        def callback
          unless google_enabled?
            clear_oauth_session
            redirect_to main_app_login_path, alert: 'This sign-in method is not available.'
            return
          end

          if params[:error] == 'access_denied'
            clear_oauth_session
            redirect_to main_app_login_path, alert: 'Google authentication was cancelled.'
            return
          end

          Rails.logger.info { "#{LOG_TAG} Google OAuth callback received" }

          unless valid_state?
            Rails.logger.warn { "#{LOG_TAG} Google OAuth state mismatch (possible CSRF)" }
            clear_oauth_session
            redirect_to main_app_login_path, alert: 'Authentication failed. Please try again.'
            return
          end

          oauth_result = OauthService.new.exchange_and_verify(
            code: params[:code],
            redirect_uri: google_callback_url,
            nonce: session[:google_oauth_nonce]
          )

          unless oauth_result.success?
            clear_oauth_session
            redirect_to main_app_login_path, alert: 'Authentication failed. Please try again.'
            return
          end

          mode = session[:google_oauth_mode] || 'login'
          callback_result = CallbackService.new.call(
            email: oauth_result.email,
            google_uid: oauth_result.google_uid,
            mode: mode,
            current_identity: current_identity
          )

          clear_oauth_session

          if callback_result.success?
            handle_success(callback_result, mode)
          else
            handle_failure(callback_result, mode)
          end
        end

        private

        def google_enabled?
          RSB::Auth.credentials.enabled?(:google)
        rescue StandardError
          false
        end

        def google_configured?
          client_id = RSB::Settings.get('auth.credentials.google.client_id')
          client_secret = RSB::Settings.get('auth.credentials.google.client_secret')
          client_id.present? && client_secret.present?
        end

        def valid_state?
          params[:state].present? &&
            session[:google_oauth_state].present? &&
            ActiveSupport::SecurityUtils.secure_compare(
              params[:state].to_s,
              session[:google_oauth_state].to_s
            )
        end

        def handle_success(result, _mode)
          case result.action
          when :linked, :already_linked
            flash_msg = result.action == :linked ? 'Google account linked successfully.' : 'Google account is already linked.'
            redirect_to rsb_auth.account_path, notice: flash_msg
          else # :logged_in, :registered
            create_auth_session(result.identity)
            if result.identity.complete?
              redirect_to main_app.root_path, notice: 'Signed in.'
            else
              redirect_to rsb_auth.account_path, alert: 'Please complete your profile.'
            end
          end
        end

        def handle_failure(result, mode)
          redirect_path = mode == 'link' ? rsb_auth.account_path : main_app_login_path
          redirect_to redirect_path, alert: result.error
        end

        def create_auth_session(identity)
          session_record = RSB::Auth::SessionService.new.create(
            identity: identity,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          cookies.signed[:rsb_session_token] = {
            value: session_record.token,
            httponly: true,
            same_site: :lax,
            secure: Rails.env.production?
          }
        end

        def clear_oauth_session
          session.delete(:google_oauth_state)
          session.delete(:google_oauth_nonce)
          session.delete(:google_oauth_mode)
        end

        def sanitize_login_hint(hint)
          return nil if hint.blank?

          hint.strip.truncate(255, omission: '')
        end

        def google_callback_url
          url_for(action: :callback, only_path: false)
        end

        def main_app_login_path
          rsb_auth.new_session_path
        rescue StandardError
          '/auth/session/new'
        end

        def rsb_auth
          RSB::Auth::Engine.routes.url_helpers
        end
      end
    end
  end
end
