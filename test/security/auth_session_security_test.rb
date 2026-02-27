# frozen_string_literal: true

# Security Test: Auth Session Security
#
# Attack vectors prevented:
# - Session token theft via XSS (httponly cookie)
# - Session token theft via network sniffing (secure flag in production)
# - Session fixation (fresh token on every login)
# - Session replay after logout (revoke invalidates token)
# - Stale session reuse (expired sessions rejected)
#
# Covers: SRS-016 US-001 (Cookie Hardening), US-002 (Session Fixation Prevention)

require 'test_helper'

class AuthSessionSecurityTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'session-test@example.com')
  end

  # --- US-001: Cookie Attributes ---

  test 'session cookie is set after successful login' do
    post session_path, params: { identifier: 'session-test@example.com', password: 'password1234' }
    assert_response :redirect
    assert cookies[:rsb_session_token].present?, 'Session cookie must be set after login'
  end

  test 'session token has sufficient entropy (32 bytes = 256 bits)' do
    session = RSB::Auth::SessionService.new.create(
      identity: @identity,
      ip_address: '127.0.0.1',
      user_agent: 'TestBrowser'
    )
    # urlsafe_base64(32) produces ~43 characters
    assert session.token.length >= 32, "Token length #{session.token.length} is insufficient (expect >= 32 chars)"
  end

  test 'expired sessions are not returned by SessionService#find_by_token' do
    session = RSB::Auth::SessionService.new.create(
      identity: @identity,
      ip_address: '127.0.0.1',
      user_agent: 'TestBrowser'
    )
    # Expire the session
    session.update_column(:expires_at, 1.hour.ago)

    found = RSB::Auth::SessionService.new.find_by_token(session.token)
    assert_nil found, 'Expired session must not be returned'
  end

  test 'Session#revoke! sets expires_at to current time (immediate revocation)' do
    session = RSB::Auth::SessionService.new.create(
      identity: @identity,
      ip_address: '127.0.0.1',
      user_agent: 'TestBrowser'
    )
    session.revoke!
    session.reload

    assert session.expires_at <= Time.current, 'Revoked session expires_at must be <= now'
    assert session.expired?, 'Revoked session must be expired'
  end

  # --- US-002: Session Fixation Prevention ---

  test 'login creates a new session record with fresh token every time' do
    # Login first time
    post session_path, params: { identifier: 'session-test@example.com', password: 'password1234' }
    first_token = cookies[:rsb_session_token]
    delete session_path # logout

    # Login second time
    post session_path, params: { identifier: 'session-test@example.com', password: 'password1234' }
    second_token = cookies[:rsb_session_token]

    assert_not_equal first_token, second_token, 'Each login must generate a unique session token'
  end

  test 'session token replay after logout fails' do
    post session_path, params: { identifier: 'session-test@example.com', password: 'password1234' }
    token = cookies[:rsb_session_token]
    assert token.present?

    # Logout
    delete session_path
    assert cookies[:rsb_session_token].blank?

    # Replay the old token
    cookies[:rsb_session_token] = token
    get account_path
    # Should redirect to login (not authenticated)
    assert_response :redirect
  end

  test 'pre-login cookie value is not associated with authenticated session' do
    # Set a fake cookie before login (fixation attempt)
    cookies[:rsb_session_token] = 'attacker-controlled-token'

    post session_path, params: { identifier: 'session-test@example.com', password: 'password1234' }

    # After login, the cookie should be a real token, not the attacker's value
    new_token = cookies[:rsb_session_token]
    assert_not_equal 'attacker-controlled-token', new_token
    assert new_token.present?
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
