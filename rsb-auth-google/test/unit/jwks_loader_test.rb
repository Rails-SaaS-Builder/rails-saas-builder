# frozen_string_literal: true

require 'test_helper'
require 'webmock/minitest'

class RSB::Auth::Google::JwksLoaderTest < ActiveSupport::TestCase
  GOOGLE_JWKS_URI = 'https://www.googleapis.com/oauth2/v3/certs'

  setup do
    RSB::Auth::Google::JwksLoader.invalidate_cache!
    Rails.cache.clear
    WebMock.reset!
  end

  teardown do
    RSB::Auth::Google::JwksLoader.invalidate_cache!
    Rails.cache.clear
    WebMock.reset!
  end

  test 'fetches JWKS keys from Google endpoint' do
    jwks_response = { 'keys' => [build_test_jwk('kid-1')] }
    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(status: 200, body: jwks_response.to_json, headers: { 'Content-Type' => 'application/json' })

    keys = RSB::Auth::Google::JwksLoader.fetch_keys
    assert_kind_of Array, keys
    assert_equal 1, keys.size
    assert_requested :get, GOOGLE_JWKS_URI, times: 1
  end

  test 'caches JWKS keys in Rails.cache' do
    jwks_response = { 'keys' => [build_test_jwk('kid-cached')] }
    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(status: 200, body: jwks_response.to_json, headers: { 'Content-Type' => 'application/json' })

    # First call fetches
    RSB::Auth::Google::JwksLoader.fetch_keys
    # Second call uses cache
    RSB::Auth::Google::JwksLoader.fetch_keys

    assert_requested :get, GOOGLE_JWKS_URI, times: 1
  end

  test 'invalidate_cache! forces fresh fetch' do
    jwks_response = { 'keys' => [build_test_jwk('kid-fresh')] }
    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(status: 200, body: jwks_response.to_json, headers: { 'Content-Type' => 'application/json' })

    RSB::Auth::Google::JwksLoader.fetch_keys
    RSB::Auth::Google::JwksLoader.invalidate_cache!
    RSB::Auth::Google::JwksLoader.fetch_keys

    assert_requested :get, GOOGLE_JWKS_URI, times: 2
  end

  test 'find_key returns the key matching kid' do
    jwks_response = { 'keys' => [build_test_jwk('kid-a'), build_test_jwk('kid-b')] }
    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(status: 200, body: jwks_response.to_json, headers: { 'Content-Type' => 'application/json' })

    key = RSB::Auth::Google::JwksLoader.find_key('kid-b')
    assert_not_nil key
  end

  test 'find_key returns nil for unknown kid' do
    jwks_response = { 'keys' => [build_test_jwk('kid-known')] }
    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(status: 200, body: jwks_response.to_json, headers: { 'Content-Type' => 'application/json' })

    key = RSB::Auth::Google::JwksLoader.find_key('kid-unknown')
    assert_nil key
  end

  test 'find_key retries with fresh keys on kid mismatch' do
    # First call: old key set
    old_keys = { 'keys' => [build_test_jwk('kid-old')] }
    # Second call (after invalidation): new key set
    new_keys = { 'keys' => [build_test_jwk('kid-new')] }

    stub_request(:get, GOOGLE_JWKS_URI)
      .to_return(
        { status: 200, body: old_keys.to_json, headers: { 'Content-Type' => 'application/json' } },
        { status: 200, body: new_keys.to_json, headers: { 'Content-Type' => 'application/json' } }
      )

    key = RSB::Auth::Google::JwksLoader.find_key('kid-new')
    assert_not_nil key
    assert_requested :get, GOOGLE_JWKS_URI, times: 2
  end

  test 'raises error when Google JWKS endpoint is unreachable' do
    stub_request(:get, GOOGLE_JWKS_URI).to_timeout

    assert_raises(RSB::Auth::Google::JwksLoader::FetchError) do
      RSB::Auth::Google::JwksLoader.fetch_keys
    end
  end

  private

  def build_test_jwk(kid)
    rsa_key = OpenSSL::PKey::RSA.generate(2048)
    jwk = JWT::JWK.new(rsa_key, kid: kid)
    jwk.export.transform_keys(&:to_s)
  end
end
