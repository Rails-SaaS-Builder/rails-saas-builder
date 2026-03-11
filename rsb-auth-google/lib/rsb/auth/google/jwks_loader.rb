# frozen_string_literal: true

require 'net/http'
require 'json'

module RSB
  module Auth
    module Google
      # Fetches and caches Google's public keys (JWKS) for JWT verification.
      #
      # Keys are cached in Rails.cache with a 1-hour TTL. On kid mismatch
      # (key rotation), the cache is invalidated and keys are re-fetched once.
      #
      # @example
      #   key = RSB::Auth::Google::JwksLoader.find_key('kid-123')
      #   JWT.decode(token, key, true, algorithm: 'RS256')
      class JwksLoader
        GOOGLE_JWKS_URI = 'https://www.googleapis.com/oauth2/v3/certs'
        CACHE_KEY = 'rsb:auth:google:jwks'
        CACHE_TTL = 3600 # 1 hour in seconds

        class FetchError < StandardError; end

        class << self
          # Fetches Google's JWKS keys. Uses an in-memory cache with 1-hour TTL.
          #
          # @return [Array<JWT::JWK>] array of JWK key objects
          # @raise [FetchError] if the HTTP request fails
          def fetch_keys
            if @cached_keys && @cached_at && (Time.current - @cached_at) < CACHE_TTL
              Rails.logger.debug { "#{RSB::Auth::Google::LOG_TAG} Using cached Google JWKS keys" }
              return @cached_keys
            end

            Rails.logger.debug { "#{RSB::Auth::Google::LOG_TAG} Fetching Google JWKS keys" }
            @cached_keys = fetch_keys_from_google
            @cached_at = Time.current
            @cached_keys
          end

          # Finds a JWK key by its key ID (kid).
          # If the kid is not found in the cached keys, invalidates the cache
          # and retries once (handles Google key rotation).
          #
          # @param kid [String] the key ID from the JWT header
          # @return [OpenSSL::PKey::RSA, nil] the RSA public key, or nil if not found
          def find_key(kid)
            keys = fetch_keys
            key = find_in_keyset(keys, kid)
            return key if key

            # Key rotation: invalidate cache and retry once
            Rails.logger.debug { "#{RSB::Auth::Google::LOG_TAG} kid=#{kid} not found, refreshing JWKS" }
            invalidate_cache!
            keys = fetch_keys
            find_in_keyset(keys, kid)
          end

          # Invalidates the cached JWKS keys, forcing a fresh fetch.
          #
          # @return [void]
          def invalidate_cache!
            @cached_keys = nil
            @cached_at = nil
          end

          private

          def fetch_keys_from_google
            uri = URI(GOOGLE_JWKS_URI)
            response = Net::HTTP.get_response(uri)

            unless response.is_a?(Net::HTTPSuccess)
              raise FetchError, "Google JWKS fetch failed: HTTP #{response.code}"
            end

            jwks_data = JSON.parse(response.body)
            jwks_data['keys'].map { |key_data| JWT::JWK.new(key_data) }
          rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
            raise FetchError, "Google JWKS fetch failed: #{e.class}: #{e.message}"
          end

          def find_in_keyset(keys, kid)
            jwk = keys.find { |k| k[:kid] == kid }
            jwk&.verify_key
          end
        end
      end
    end
  end
end
