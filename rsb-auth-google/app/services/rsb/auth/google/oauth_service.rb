# frozen_string_literal: true

require 'net/http'
require 'json'

module RSB
  module Auth
    module Google
      # Exchanges a Google authorization code for tokens and verifies the id_token JWT.
      #
      # @example
      #   service = RSB::Auth::Google::OauthService.new
      #   result = service.exchange_and_verify(
      #     code: params[:code],
      #     redirect_uri: callback_url,
      #     nonce: session[:google_oauth_nonce]
      #   )
      #   if result.success?
      #     # result.email, result.google_uid available
      #   end
      class OauthService
        GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token'
        VALID_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'].freeze

        Result = Data.define(:success?, :email, :google_uid, :error)

        # Exchanges the authorization code for tokens, then verifies the id_token JWT.
        #
        # @param code [String] the authorization code from Google
        # @param redirect_uri [String] the callback URL (must match what was sent to Google)
        # @param nonce [String] the nonce stored in the session for replay prevention
        # @return [OauthService::Result] result with email and google_uid on success, error on failure
        def exchange_and_verify(code:, redirect_uri:, nonce:)
          # Step 1: Exchange code for tokens
          token_response = exchange_code(code, redirect_uri)
          return failure(:token_exchange_failed) unless token_response

          id_token = token_response['id_token']
          return failure(:token_exchange_failed) unless id_token.present?

          # Step 2: Verify the id_token JWT
          claims = verify_id_token(id_token, nonce)
          return failure(:jwt_verification_failed) unless claims

          email = claims['email']
          google_uid = claims['sub']

          Rails.logger.info { "#{LOG_TAG} Google token exchange successful for email=#{email}" }

          Result.new(
            success?: true,
            email: email,
            google_uid: google_uid,
            error: nil
          )
        end

        private

        def exchange_code(code, redirect_uri)
          client_id = RSB::Settings.get('auth.credentials.google.client_id')
          client_secret = RSB::Settings.get('auth.credentials.google.client_secret')

          uri = URI(GOOGLE_TOKEN_URI)
          response = Net::HTTP.post_form(uri, {
                                           'code' => code,
                                           'client_id' => client_id,
                                           'client_secret' => client_secret,
                                           'redirect_uri' => redirect_uri,
                                           'grant_type' => 'authorization_code'
                                         })

          unless response.is_a?(Net::HTTPSuccess)
            Rails.logger.error { "#{LOG_TAG} Google token exchange failed: HTTP #{response.code} — #{response.body}" }
            return nil
          end

          JSON.parse(response.body)
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError, JSON::ParserError => e
          Rails.logger.error { "#{LOG_TAG} Google token exchange failed: #{e.class}: #{e.message}" }
          nil
        end

        def verify_id_token(id_token, nonce)
          # Decode header to get kid (key ID)
          header = JWT.decode(id_token, nil, false).last
          kid = header['kid']

          # Find the matching public key
          key = JwksLoader.find_key(kid)
          unless key
            Rails.logger.warn { "#{LOG_TAG} Google id_token verification failed: unknown kid=#{kid}" }
            return nil
          end

          # Verify signature and decode claims
          client_id = RSB::Settings.get('auth.credentials.google.client_id')
          claims = JWT.decode(
            id_token,
            key,
            true,
            {
              algorithm: 'RS256',
              verify_iss: true,
              iss: VALID_ISSUERS,
              verify_aud: true,
              aud: client_id,
              verify_expiration: true
            }
          ).first

          # Validate nonce (replay prevention)
          if nonce.present? && claims['nonce'] != nonce
            Rails.logger.warn { "#{LOG_TAG} Google id_token verification failed: nonce mismatch" }
            return nil
          end

          claims
        rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature,
               JWT::InvalidIssuerError, JWT::InvalidAudError => e
          Rails.logger.warn { "#{LOG_TAG} Google id_token verification failed: #{e.class}: #{e.message}" }
          nil
        end

        def failure(error)
          Result.new(success?: false, email: nil, google_uid: nil, error: error)
        end
      end
    end
  end
end
