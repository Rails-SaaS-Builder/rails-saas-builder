# frozen_string_literal: true

module RSB
  module Auth
    module Google
      # Test helper for offline Google OAuth testing.
      # Provides stubs and helpers so host app tests never hit Google's servers.
      #
      # @example Include in test helper
      #   class ActiveSupport::TestCase
      #     include RSB::Auth::Google::TestHelper
      #   end
      #
      # @example Use in a test
      #   test 'google login works' do
      #     register_test_google_credential
      #     stub_google_oauth(email: 'user@gmail.com', google_uid: '12345')
      #     response = simulate_google_login(email: 'user@gmail.com', google_uid: '12345')
      #     assert_response :redirect
      #   end
      module TestHelper
        extend ActiveSupport::Concern

        included do
          setup do
            RSB::Auth::Google.reset!
          end

          teardown do
            unstub_google_oauth
            RSB::Auth::Google.reset!
          end
        end

        # Registers the Google credential type with test-safe settings.
        # Call this in test setup when you need Google OAuth available.
        #
        # @return [void]
        def register_test_google_credential
          # Register Google settings if not already registered
          register_google_settings_for_test

          # Register the credential type if not already registered
          unless google_credential_registered?
            RSB::Auth.credentials.register(
              RSB::Auth::CredentialDefinition.new(
                key: :google,
                class_name: 'RSB::Auth::Google::Credential',
                authenticatable: true,
                registerable: true,
                label: 'Google',
                icon: 'google',
                form_partial: 'rsb/auth/google/credentials/google',
                redirect_url: '/auth/oauth/google',
                admin_form_partial: nil
              )
            )
          end

          # Set test credentials
          RSB::Settings.set('auth.credentials.google.client_id', 'test-google-client-id')
          RSB::Settings.set('auth.credentials.google.client_secret', 'test-google-client-secret')
          RSB::Settings.set('auth.credentials.google.enabled', true)
        end

        # Stubs OauthService to return a successful result with the given claims.
        # No HTTP calls are made to Google -- fully offline.
        #
        # @param email [String] Google email to return
        # @param google_uid [String] Google user ID (sub claim) to return
        # @return [void]
        def stub_google_oauth(email:, google_uid:)
          result = OauthService::Result.new(
            success?: true,
            email: email,
            google_uid: google_uid,
            error: nil
          )

          # Replace OauthService#exchange_and_verify with a stub
          @_original_exchange_and_verify = OauthService.instance_method(:exchange_and_verify)
          OauthService.define_method(:exchange_and_verify) { |**_kwargs| result }
        end

        # Removes the OauthService stub, restoring original behavior.
        #
        # @return [void]
        def unstub_google_oauth
          return unless @_original_exchange_and_verify

          OauthService.define_method(:exchange_and_verify, @_original_exchange_and_verify)
          @_original_exchange_and_verify = nil
        end

        # Performs the full Google OAuth login flow in a test.
        # Visits the redirect endpoint (stores state in session),
        # then hits the callback with the stubbed Google response.
        #
        # @param email [String] Google email
        # @param google_uid [String] Google user ID
        # @param mode [String] "login" or "signup" (default: "login")
        # @return [ActionDispatch::Response] the callback response
        def simulate_google_login(email:, google_uid:, mode: 'login')
          stub_google_oauth(email: email, google_uid: google_uid)

          # Step 1: GET redirect endpoint (stores state in session)
          get "/auth/oauth/google?mode=#{mode}"

          # Extract state from session
          state = session[:google_oauth_state]

          # Step 2: GET callback with code + state
          get "/auth/oauth/google/callback?code=test-auth-code&state=#{state}"

          response
        end

        # Performs the Google OAuth link flow for an authenticated identity.
        #
        # @param identity [RSB::Auth::Identity] the identity to link Google to
        # @param email [String] Google email
        # @param google_uid [String] Google user ID
        # @return [ActionDispatch::Response] the callback response
        def simulate_google_link(identity:, email:, google_uid:)
          stub_google_oauth(email: email, google_uid: google_uid)

          # Step 1: GET redirect endpoint with mode=link
          get '/auth/oauth/google?mode=link'

          # Extract state from session
          state = session[:google_oauth_state]

          # Step 2: GET callback
          get "/auth/oauth/google/callback?code=test-auth-code&state=#{state}"

          response
        end

        # Builds a fake id_token claims hash for unit testing services directly.
        # Does NOT create a signed JWT -- just the claims hash.
        #
        # @param email [String] Google email
        # @param google_uid [String] Google user ID (sub claim)
        # @param nonce [String, nil] optional nonce
        # @return [Hash] id_token claims hash
        def build_google_id_token(email:, google_uid:, nonce: nil)
          client_id = begin
            RSB::Settings.get('auth.credentials.google.client_id')
          rescue StandardError
            'test-google-client-id'
          end

          {
            'iss' => 'https://accounts.google.com',
            'aud' => client_id,
            'sub' => google_uid,
            'email' => email,
            'email_verified' => true,
            'exp' => 1.hour.from_now.to_i,
            'iat' => Time.current.to_i,
            'nonce' => nonce
          }.compact
        end

        private

        def google_credential_registered?
          RSB::Auth.credentials.find(:google).present?
        rescue StandardError
          false
        end

        def register_google_settings_for_test
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
          # Already registered by engine or previous test
        end
      end
    end
  end
end
