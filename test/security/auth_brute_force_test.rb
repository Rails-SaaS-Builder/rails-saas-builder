# frozen_string_literal: true

# Security Test: Brute Force & Rate Limiting
#
# Attack vectors prevented:
# - Password guessing via repeated login attempts (credential lockout)
# - Mass login attempts (rate limiting)
# - Permanent lockout degradation (failed_attempts reset on success)
#
# Covers: SRS-016 US-007 (Brute Force & Rate Limiting)

require 'test_helper'

class AuthBruteForceTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'brute@example.com')
  end

  test 'credential locks after lockout_threshold failed attempts' do
    threshold = RSB::Settings.get('auth.lockout_threshold')

    threshold.times do
      RSB::Auth::AuthenticationService.new.call(
        identifier: 'brute@example.com',
        password: 'wrong_password'
      )
    end

    @credential.reload
    assert @credential.locked?, "Credential must be locked after #{threshold} failed attempts"
    assert @credential.locked_until > Time.current
  end

  test 'locked credential cannot authenticate even with correct password' do
    @credential.update_columns(
      failed_attempts: 5,
      locked_until: 30.minutes.from_now
    )

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'brute@example.com',
      password: 'password1234'
    )

    assert_not result.success?
  end

  test 'lockout expires after lockout_duration' do
    duration = RSB::Settings.get('auth.lockout_duration')
    @credential.update_columns(
      failed_attempts: 5,
      locked_until: Time.current + duration.to_i.seconds
    )

    travel (duration.to_i + 1).seconds do
      assert_not @credential.locked?, 'Credential must be unlocked after lockout_duration'

      result = RSB::Auth::AuthenticationService.new.call(
        identifier: 'brute@example.com',
        password: 'password1234'
      )

      assert result.success?, 'Login must succeed after lockout expires'
    end
  end

  test 'failed_attempts resets to 0 on successful login' do
    # Accumulate some failed attempts (but not enough to lock)
    3.times do
      RSB::Auth::AuthenticationService.new.call(
        identifier: 'brute@example.com',
        password: 'wrong_password'
      )
    end

    @credential.reload
    assert_equal 3, @credential.failed_attempts

    # Successful login
    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'brute@example.com',
      password: 'password1234'
    )

    assert result.success?
    @credential.reload
    assert_equal 0, @credential.failed_attempts,
                 'failed_attempts must reset to 0 on successful login'
  end

  test 'rate limiting on login endpoint rejects excessive requests' do
    # Rate limit is 10 per 60s on login
    11.times do
      post session_path, params: { identifier: 'brute@example.com', password: 'wrong' }
    end

    assert_response :too_many_requests,
                    'Login endpoint must return 429 after rate limit exceeded'
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
