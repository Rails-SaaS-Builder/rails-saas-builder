# frozen_string_literal: true

require 'test_helper'
require 'webmock/minitest'

module RSB
  module Auth
    module Google
      class OauthFlowTest < ActionDispatch::IntegrationTest
        include RSB::Auth::Engine.routes.url_helpers

        setup do
          register_all_settings
          register_all_credentials
          register_google_test_settings
          RSB::Settings.set('auth.credentials.google.client_id', 'test-client-id.apps.googleusercontent.com')
          RSB::Settings.set('auth.credentials.google.client_secret', 'test-client-secret')
          RSB::Settings.set('auth.credentials.google.enabled', true)
          Rails.cache.clear
          WebMock.reset!
        end

        teardown do
          Rails.cache.clear
          WebMock.reset!
        end

        # --- REDIRECT ACTION ---

        test 'GET /auth/oauth/google redirects to Google consent screen' do
          get '/auth/oauth/google'

          assert_response :redirect
          location = response.location
          assert_match %r{accounts\.google\.com/o/oauth2/v2/auth}, location
          assert_match(/client_id=test-client-id/, location)
          assert_match(/response_type=code/, location)
          assert_match(/scope=openid\+email/, location)
          assert_match(/state=/, location)
          assert_match(/nonce=/, location)
        end

        test 'GET /auth/oauth/google stores state and nonce in session' do
          get '/auth/oauth/google'

          assert_not_nil session[:google_oauth_state]
          assert_not_nil session[:google_oauth_nonce]
          assert_not_nil session[:google_oauth_mode]
        end

        test 'GET /auth/oauth/google passes login_hint when identifier present' do
          get '/auth/oauth/google', params: { login_hint: 'user@gmail.com' }

          assert_response :redirect
          assert_match(/login_hint=user/, response.location)
        end

        test 'GET /auth/oauth/google passes mode to session' do
          get '/auth/oauth/google', params: { mode: 'signup' }

          assert_equal 'signup', session[:google_oauth_mode]
        end

        test 'GET /auth/oauth/google defaults mode to login' do
          get '/auth/oauth/google'

          assert_equal 'login', session[:google_oauth_mode]
        end

        test 'GET /auth/oauth/google with link mode requires authentication' do
          get '/auth/oauth/google', params: { mode: 'link' }

          # When not authenticated, should redirect to login
          assert_response :redirect
          assert_match %r{/auth/session/new}, response.location
        end

        test 'GET /auth/oauth/google when disabled redirects with flash error' do
          RSB::Settings.set('auth.credentials.google.enabled', false)

          get '/auth/oauth/google'

          assert_response :redirect
          follow_redirect!
          assert_match(/not available/i, flash[:alert])
        end

        test 'GET /auth/oauth/google when not configured redirects with flash error' do
          RSB::Settings.set('auth.credentials.google.client_id', '')

          get '/auth/oauth/google'

          assert_response :redirect
          follow_redirect!
          assert_match(/not configured/i, flash[:alert])
        end

        test 'GET /auth/oauth/google sanitizes login_hint' do
          get '/auth/oauth/google', params: { login_hint: '  User@Gmail.COM  ' }

          assert_response :redirect
          location = response.location
          assert_match(/login_hint=/, location)
        end

        # --- CALLBACK ACTION ---

        test 'GET /auth/oauth/google/callback with valid code creates session' do
          rsa_key, kid = generate_test_key

          get '/auth/oauth/google'
          stored_state = session[:google_oauth_state]
          stored_nonce = session[:google_oauth_nonce]

          id_token = build_signed_id_token(
            rsa_key: rsa_key, kid: kid,
            email: 'callback@gmail.com', sub: 'callback-uid',
            nonce: stored_nonce
          )

          stub_token_exchange(id_token: id_token)
          stub_jwks(rsa_key: rsa_key, kid: kid)

          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          get '/auth/oauth/google/callback', params: { code: 'auth-code', state: stored_state }

          assert_response :redirect
          assert_not_nil cookies[:rsb_session_token]
        end

        test 'GET /auth/oauth/google/callback with state mismatch redirects with error' do
          get '/auth/oauth/google'

          get '/auth/oauth/google/callback', params: { code: 'auth-code', state: 'wrong-state' }

          assert_response :redirect
          follow_redirect!
          assert_match(/failed.*try again/i, flash[:alert])
        end

        test 'GET /auth/oauth/google/callback with error=access_denied shows cancellation message' do
          get '/auth/oauth/google'

          get '/auth/oauth/google/callback', params: { error: 'access_denied', state: session[:google_oauth_state] }

          assert_response :redirect
          follow_redirect!
          assert_match(/cancelled/i, flash[:alert])
        end

        test 'GET /auth/oauth/google/callback clears session OAuth keys after processing' do
          rsa_key, kid = generate_test_key
          get '/auth/oauth/google'
          stored_state = session[:google_oauth_state]
          stored_nonce = session[:google_oauth_nonce]

          id_token = build_signed_id_token(
            rsa_key: rsa_key, kid: kid,
            email: 'clear@gmail.com', sub: 'clear-uid',
            nonce: stored_nonce
          )
          stub_token_exchange(id_token: id_token)
          stub_jwks(rsa_key: rsa_key, kid: kid)
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          get '/auth/oauth/google/callback', params: { code: 'auth-code', state: stored_state }

          assert_nil session[:google_oauth_state]
          assert_nil session[:google_oauth_nonce]
          assert_nil session[:google_oauth_mode]
        end

        test 'GET /auth/oauth/google/callback when Google auth disabled redirects with error' do
          get '/auth/oauth/google'
          stored_state = session[:google_oauth_state]
          RSB::Settings.set('auth.credentials.google.enabled', false)

          get '/auth/oauth/google/callback', params: { code: 'auth-code', state: stored_state }

          assert_response :redirect
          follow_redirect!
          assert_match(/not available/i, flash[:alert])
        end

        # --- VIEW PARTIAL ---

        test 'login page includes Google button when credential is enabled' do
          get '/auth/session/new'

          assert_response :success
          assert_match(/Google/i, response.body)
          assert_match %r{/auth/oauth/google}, response.body
        end

        test 'registration page includes Google button when credential is enabled and registerable' do
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          get '/auth/registration/new'

          assert_response :success
          assert_match(/Google/i, response.body)
        end

        test 'login page does not show Google when disabled' do
          RSB::Settings.set('auth.credentials.google.enabled', false)

          get '/auth/session/new'

          assert_response :success
          assert_no_match(%r{/auth/oauth/google}, response.body)
        end

        private

        def default_url_options
          { host: 'localhost' }
        end

        def generate_test_key
          rsa_key = OpenSSL::PKey::RSA.generate(2048)
          kid = SecureRandom.hex(8)
          [rsa_key, kid]
        end

        def build_signed_id_token(rsa_key:, kid:, email:, sub:, nonce: nil)
          payload = {
            'iss' => 'https://accounts.google.com',
            'aud' => RSB::Settings.get('auth.credentials.google.client_id'),
            'sub' => sub,
            'email' => email,
            'email_verified' => true,
            'exp' => 1.hour.from_now.to_i,
            'iat' => Time.current.to_i,
            'nonce' => nonce
          }.compact
          JWT.encode(payload, rsa_key, 'RS256', { kid: kid })
        end

        def stub_token_exchange(id_token:)
          stub_request(:post, 'https://oauth2.googleapis.com/token')
            .to_return(
              status: 200,
              body: { 'access_token' => 'fake', 'id_token' => id_token, 'token_type' => 'Bearer', 'expires_in' => 3600 }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        def stub_jwks(rsa_key:, kid:)
          jwk = JWT::JWK.new(rsa_key, kid: kid)
          stub_request(:get, 'https://www.googleapis.com/oauth2/v3/certs')
            .to_return(
              status: 200,
              body: { 'keys' => [jwk.export.transform_keys(&:to_s)] }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        def register_google_test_settings
          schema = RSB::Settings::Schema.new('auth') do
            setting :'credentials.google.client_id', type: :string, default: ''
            setting :'credentials.google.client_secret', type: :string, default: ''
            setting :'credentials.google.auto_merge_by_email', type: :boolean, default: false
            setting :'credentials.google.enabled', type: :boolean, default: true
            setting :'credentials.google.registerable', type: :boolean, default: true
            setting :'credentials.google.verification_required', type: :boolean, default: false
            setting :'credentials.google.auto_verify_on_signup', type: :boolean, default: true
            setting :'credentials.google.allow_login_unverified', type: :boolean, default: true
          end
          RSB::Settings.registry.register(schema)
        rescue RSB::Settings::DuplicateSettingError
          # Already registered by engine
        end
      end
    end
  end
end
