# frozen_string_literal: true

require 'test_helper'
require 'webmock/minitest'

class RSB::Auth::Google::OauthServiceTest < ActiveSupport::TestCase
  GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token'

  setup do
    register_all_settings
    register_all_credentials
    RSB::Auth::Google::JwksLoader.invalidate_cache!
    Rails.cache.clear
    WebMock.reset!

    # Register Google-specific settings for tests
    register_google_settings
    RSB::Settings.set('auth.credentials.google.client_id', 'test-client-id.apps.googleusercontent.com')
    RSB::Settings.set('auth.credentials.google.client_secret', 'test-client-secret')
  end

  teardown do
    RSB::Auth::Google::JwksLoader.invalidate_cache!
    Rails.cache.clear
    WebMock.reset!
  end

  test 'exchange_and_verify returns success with email and google_uid' do
    rsa_key, kid = generate_test_key
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'google-uid-123',
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/auth/oauth/google/callback',
      nonce: 'test-nonce'
    )

    assert result.success?
    assert_equal 'user@gmail.com', result.email
    assert_equal 'google-uid-123', result.google_uid
    assert_nil result.error
  end

  test 'returns failure when token exchange fails' do
    stub_request(:post, GOOGLE_TOKEN_URI)
      .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'bad-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :token_exchange_failed, result.error
  end

  test 'returns failure when JWT signature is invalid' do
    # Sign with one key, verify with a different key
    signing_key, _kid = generate_test_key
    verify_key, verify_kid = generate_test_key

    id_token = build_signed_id_token(
      rsa_key: signing_key,
      kid: 'wrong-kid',
      email: 'user@gmail.com',
      sub: 'uid-123',
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: verify_key, kid: verify_kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :jwt_verification_failed, result.error
  end

  test 'returns failure when aud claim does not match client_id' do
    rsa_key, kid = generate_test_key
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'uid-123',
      aud: 'wrong-client-id',
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :jwt_verification_failed, result.error
  end

  test 'returns failure when token is expired' do
    rsa_key, kid = generate_test_key
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'uid-123',
      exp: 1.hour.ago.to_i,
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :jwt_verification_failed, result.error
  end

  test 'returns failure when nonce does not match' do
    rsa_key, kid = generate_test_key
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'uid-123',
      nonce: 'original-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'different-nonce'
    )

    assert_not result.success?
    assert_equal :jwt_verification_failed, result.error
  end

  test 'returns failure when issuer is invalid' do
    rsa_key, kid = generate_test_key
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'uid-123',
      iss: 'https://evil.com',
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :jwt_verification_failed, result.error
  end

  test 'accepts both google issuer formats' do
    rsa_key, kid = generate_test_key

    # Test with "accounts.google.com" (no https prefix)
    id_token = build_signed_id_token(
      rsa_key: rsa_key,
      kid: kid,
      email: 'user@gmail.com',
      sub: 'uid-123',
      iss: 'accounts.google.com',
      nonce: 'test-nonce'
    )

    stub_token_exchange(id_token: id_token)
    stub_jwks(rsa_key: rsa_key, kid: kid)

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert result.success?
  end

  test 'returns failure when Google token endpoint returns network error' do
    stub_request(:post, GOOGLE_TOKEN_URI).to_timeout

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(
      code: 'auth-code',
      redirect_uri: 'http://localhost/callback',
      nonce: 'test-nonce'
    )

    assert_not result.success?
    assert_equal :token_exchange_failed, result.error
  end

  private

  def generate_test_key
    rsa_key = OpenSSL::PKey::RSA.generate(2048)
    kid = SecureRandom.hex(8)
    [rsa_key, kid]
  end

  def build_signed_id_token(rsa_key:, kid:, email:, sub:, nonce: nil,
                             iss: 'https://accounts.google.com',
                             aud: nil, exp: nil)
    payload = {
      'iss' => iss,
      'aud' => aud || RSB::Settings.get('auth.credentials.google.client_id'),
      'sub' => sub,
      'email' => email,
      'email_verified' => true,
      'exp' => exp || 1.hour.from_now.to_i,
      'iat' => Time.current.to_i,
      'nonce' => nonce
    }.compact

    JWT.encode(payload, rsa_key, 'RS256', { kid: kid })
  end

  def stub_token_exchange(id_token:)
    stub_request(:post, GOOGLE_TOKEN_URI)
      .to_return(
        status: 200,
        body: {
          'access_token' => 'fake-access-token',
          'id_token' => id_token,
          'token_type' => 'Bearer',
          'expires_in' => 3600
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_jwks(rsa_key:, kid:)
    jwk = JWT::JWK.new(rsa_key, kid: kid)
    jwks_response = { 'keys' => [jwk.export.transform_keys(&:to_s)] }

    stub_request(:get, 'https://www.googleapis.com/oauth2/v3/certs')
      .to_return(
        status: 200,
        body: jwks_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def register_google_settings
    schema = RSB::Settings::Schema.new('auth') do
      setting :'credentials.google.client_id',
              type: :string,
              default: '',
              description: 'Google OAuth client ID'

      setting :'credentials.google.client_secret',
              type: :string,
              default: '',
              description: 'Google OAuth client secret'
    end
    RSB::Settings.registry.register(schema)
  rescue RSB::Settings::DuplicateSettingError
    # Already registered
  end
end
