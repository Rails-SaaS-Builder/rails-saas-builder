# frozen_string_literal: true

# Cross-Gem Regression: Google OAuth Authentication (TDD-017)
#
# Verifies that rsb-auth-google works correctly when all engines are mounted
# together: credential registration, settings resolution, full OAuth flow,
# auto-merge integration, and admin hooks.

require 'test_helper'
require 'webmock/minitest'

class GoogleOauthRegressionTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    register_test_google_credential
    Rails.cache.clear
    WebMock.reset!
  end

  teardown do
    Rails.cache.clear
    WebMock.reset!
    RSB::Admin.reset!
  end

  # --- Credential Registration ---

  test 'Google credential type is registered in credential registry across gems' do
    defn = RSB::Auth.credentials.find(:google)
    assert_not_nil defn, 'Google credential must be registered when rsb-auth-google is loaded'
    assert_equal :google, defn.key
    assert_equal 'RSB::Auth::Google::Credential', defn.class_name
    assert defn.authenticatable
    assert defn.registerable
  end

  test 'Google credential has redirect_url for OAuth flow' do
    defn = RSB::Auth.credentials.find(:google)
    assert_equal '/auth/oauth/google', defn.redirect_url
  end

  test 'Google credential appears in enabled credentials list' do
    RSB::Settings.set('auth.credentials.google.enabled', true)
    enabled = RSB::Auth.credentials.enabled
    google = enabled.find { |d| d.key == :google }
    assert_not_nil google, 'Google should appear in enabled credentials'
  end

  # --- Settings Registration & Resolution ---

  test 'Google settings are registered and resolvable via RSB::Settings' do
    assert_equal 'test-google-client-id', RSB::Settings.get('auth.credentials.google.client_id')
    assert_equal 'test-google-client-secret', RSB::Settings.get('auth.credentials.google.client_secret')
    assert_equal false, RSB::Settings.get('auth.credentials.google.auto_merge_by_email')
  end

  test 'per-credential Google settings have correct defaults' do
    assert_equal true, RSB::Settings.get('auth.credentials.google.enabled')
    assert_equal true, RSB::Settings.get('auth.credentials.google.registerable')
  end

  test 'Google settings can be set and read back' do
    RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)
    assert_equal true, RSB::Settings.get('auth.credentials.google.auto_merge_by_email')

    RSB::Settings.set('auth.credentials.google.auto_merge_by_email', false)
    assert_equal false, RSB::Settings.get('auth.credentials.google.auto_merge_by_email')
  end

  # --- Full Login Flow Across Gems ---

  test 'login page shows Google option when all engines are mounted' do
    RSB::Settings.set('auth.credentials.google.enabled', true)

    get '/auth/session/new'
    assert_response :success
    assert_match(/Google/i, response.body)
  end

  test 'full Google OAuth login flow creates session across gem boundaries' do
    RSB::Settings.set('auth.registration_mode', 'open')
    RSB::Settings.set('auth.credentials.google.registerable', true)

    simulate_google_login(
      email: 'crossgem@gmail.com',
      google_uid: 'crossgem-uid'
    )

    # Should have created an identity, credential, and session
    credential = RSB::Auth::Google::Credential.find_by(provider_uid: 'crossgem-uid')
    assert_not_nil credential, 'Google credential should exist'
    assert_equal 'crossgem@gmail.com', credential.identifier
    assert credential.verified?
    assert_not_nil credential.identity
    assert_equal 'active', credential.identity.status
  end

  # --- Auto-Merge Integration with rsb-auth Settings ---

  test 'auto-merge uses auth.generic_error_messages setting from rsb-auth' do
    RSB::Settings.set('auth.credentials.google.auto_merge_by_email', false)
    RSB::Settings.set('auth.generic_error_messages', true)

    # Create an existing email/password identity
    identity = create_test_identity
    create_test_credential(identity: identity, email: 'conflict@example.com')

    # Try to log in with Google using same email
    simulate_google_login(
      email: 'conflict@example.com',
      google_uid: 'conflict-uid'
    )

    # Should show generic error (not the descriptive one)
    follow_redirect! if response.redirect?
    assert_match(/Invalid credentials/i, flash[:alert] || response.body)
  end

  test 'auto-merge creates Google credential on existing identity' do
    RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)

    identity = create_test_identity
    create_test_credential(identity: identity, email: 'merge@example.com')

    simulate_google_login(
      email: 'merge@example.com',
      google_uid: 'merge-uid'
    )

    # Google credential should be on the same identity
    google_cred = RSB::Auth::Google::Credential.find_by(provider_uid: 'merge-uid')
    assert_not_nil google_cred
    assert_equal identity.id, google_cred.identity_id
  end

  # --- Google Credential on Login Methods Page ---

  test 'Google credential appears in identity login methods' do
    identity = create_test_identity
    create_test_credential(identity: identity, email: 'account-owner@example.com')
    RSB::Auth::Google::Credential.create!(
      identity: identity,
      identifier: 'linked@gmail.com',
      provider_uid: 'linked-uid',
      verified_at: Time.current
    )

    # Sign in via POST to sessions endpoint
    post '/auth/session', params: { identifier: 'account-owner@example.com', password: 'password1234' }

    get '/auth/account'
    assert_response :success
    assert_match(/linked@gmail\.com/, response.body)
  end

  # --- Disabling Google Across Gems ---

  test 'disabling Google credential hides it from login page' do
    RSB::Settings.set('auth.credentials.google.enabled', false)

    get '/auth/session/new'
    assert_response :success
    assert_no_match(%r{/auth/oauth/google}, response.body)
  end

  # --- Admin Integration (if rsb-admin is present) ---

  test 'Google credentials are visible in admin identity view' do
    skip 'rsb-admin not loaded' unless defined?(RSB::Admin::Engine)

    identity = create_test_identity
    RSB::Auth::Google::Credential.create!(
      identity: identity,
      identifier: 'admin-visible@gmail.com',
      provider_uid: 'admin-uid',
      verified_at: Time.current
    )

    sign_in_admin(create_test_admin!)

    get "/admin/identities/#{identity.id}"
    assert_response :success
    assert_match(/admin-visible@gmail\.com/, response.body)
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
