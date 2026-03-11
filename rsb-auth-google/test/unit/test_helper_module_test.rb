# frozen_string_literal: true

require 'test_helper'

class RSB::Auth::Google::TestHelperModuleTest < ActiveSupport::TestCase
  # The TestHelper is included globally in test_helper.rb,
  # so setup/teardown hooks already run (reset! on each test).

  # --- register_test_google_credential ---

  test 'register_test_google_credential registers the google credential type' do
    register_test_google_credential

    definition = RSB::Auth.credentials.find(:google)
    assert definition.present?
    assert_equal :google, definition.key
    assert_equal 'RSB::Auth::Google::Credential', definition.class_name
  end

  test 'register_test_google_credential sets test client_id and client_secret' do
    register_test_google_credential

    assert_equal 'test-google-client-id', RSB::Settings.get('auth.credentials.google.client_id')
    assert_equal 'test-google-client-secret', RSB::Settings.get('auth.credentials.google.client_secret')
  end

  test 'register_test_google_credential enables google' do
    register_test_google_credential

    assert RSB::Settings.get('auth.credentials.google.enabled')
  end

  test 'register_test_google_credential is idempotent' do
    register_test_google_credential
    register_test_google_credential # second call should not raise

    definition = RSB::Auth.credentials.find(:google)
    assert definition.present?
  end

  # --- stub_google_oauth / unstub_google_oauth ---

  test 'stub_google_oauth replaces OauthService#exchange_and_verify' do
    register_test_google_credential

    stub_google_oauth(email: 'test@gmail.com', google_uid: '12345')

    service = RSB::Auth::Google::OauthService.new
    result = service.exchange_and_verify(code: 'fake', redirect_uri: 'http://test', nonce: 'n')

    assert result.success?
    assert_equal 'test@gmail.com', result.email
    assert_equal '12345', result.google_uid
  end

  test 'unstub_google_oauth restores original method' do
    register_test_google_credential

    original = RSB::Auth::Google::OauthService.instance_method(:exchange_and_verify)
    stub_google_oauth(email: 'test@gmail.com', google_uid: '12345')
    unstub_google_oauth

    # After unstub, the method should be the original (not our stub)
    restored = RSB::Auth::Google::OauthService.instance_method(:exchange_and_verify)
    assert_equal original, restored
  end

  # --- build_google_id_token ---

  test 'build_google_id_token returns claims hash with correct fields' do
    register_test_google_credential

    claims = build_google_id_token(email: 'user@gmail.com', google_uid: 'uid-123')

    assert_equal 'https://accounts.google.com', claims['iss']
    assert_equal 'test-google-client-id', claims['aud']
    assert_equal 'uid-123', claims['sub']
    assert_equal 'user@gmail.com', claims['email']
    assert claims['email_verified']
    assert claims['exp'].is_a?(Integer)
    assert claims['iat'].is_a?(Integer)
  end

  test 'build_google_id_token includes nonce when provided' do
    register_test_google_credential

    claims = build_google_id_token(email: 'user@gmail.com', google_uid: 'uid-123', nonce: 'abc')

    assert_equal 'abc', claims['nonce']
  end

  test 'build_google_id_token omits nonce when nil' do
    register_test_google_credential

    claims = build_google_id_token(email: 'user@gmail.com', google_uid: 'uid-123')

    assert_not claims.key?('nonce')
  end
end
