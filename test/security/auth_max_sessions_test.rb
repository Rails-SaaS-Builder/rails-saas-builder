# frozen_string_literal: true

# Security Test: Max Sessions Enforcement
#
# Attack vectors prevented:
# - Unlimited parallel sessions from compromised credentials
# - Oldest session eviction protects against session accumulation
#
# Covers: SRS-016 US-011 (Max Sessions)

require 'test_helper'

class AuthMaxSessionsTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'maxsess@example.com')
  end

  test 'max_sessions setting limits the number of active sessions' do
    max = RSB::Settings.get('auth.max_sessions')

    # Create max sessions
    sessions = max.times.map do
      RSB::Auth::SessionService.new.create(
        identity: @identity,
        ip_address: '127.0.0.1',
        user_agent: 'TestBrowser'
      )
    end

    # All should be active
    assert_equal max, @identity.sessions.active.count

    # Create one more — oldest should be evicted
    new_session = RSB::Auth::SessionService.new.create(
      identity: @identity,
      ip_address: '127.0.0.1',
      user_agent: 'TestBrowser'
    )

    assert_equal max, @identity.sessions.active.count, 'Active sessions must not exceed max'
    assert new_session.persisted?

    # Oldest session should be revoked
    sessions.first.reload
    assert sessions.first.expired?, 'Oldest session must be evicted when limit is reached'
  end

  test 'user can always log in even when max sessions reached (oldest evicted)' do
    max = RSB::Settings.get('auth.max_sessions')

    # Create max sessions
    max.times do
      RSB::Auth::SessionService.new.create(
        identity: @identity,
        ip_address: '127.0.0.1',
        user_agent: 'TestBrowser'
      )
    end

    # Login via HTTP should still work
    post session_path, params: { identifier: 'maxsess@example.com', password: 'password1234' }
    assert_response :redirect, 'User must always be able to log in'
    assert cookies[:rsb_session_token].present?
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
