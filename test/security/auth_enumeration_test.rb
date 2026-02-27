# frozen_string_literal: true

# Security Test: Account Enumeration Prevention
#
# Attack vectors prevented:
# - Enumerating valid identifiers via login error message differences
# - Timing-based account enumeration (bcrypt vs no-bcrypt response time)
# - Enumerating via password reset endpoint
#
# Covers: SRS-016 US-003 (Account Enumeration Prevention)

require 'test_helper'

class AuthEnumerationTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'enum-test@example.com')
  end

  # --- Login error messages ---

  test 'login with non-existent identifier returns same error as wrong password' do
    # Wrong password for existing user
    post session_path, params: { identifier: 'enum-test@example.com', password: 'wrongpassword' }
    wrong_password_body = response.body

    # Non-existent identifier
    post session_path, params: { identifier: 'nonexistent@example.com', password: 'anypassword' }
    no_user_body = response.body

    # Both should contain "Invalid credentials" — same error message
    assert_match(/Invalid credentials/i, wrong_password_body)
    assert_match(/Invalid credentials/i, no_user_body)
  end

  test 'generic_error_messages=true hides locked account status' do
    with_settings('auth.generic_error_messages' => true) do
      @credential.update_columns(failed_attempts: 5, locked_until: 1.hour.from_now)

      post session_path, params: { identifier: 'enum-test@example.com', password: 'password1234' }

      # Must NOT say "Account is locked" — only "Invalid credentials"
      assert_no_match(/locked/i, response.body)
      assert_match(/Invalid credentials/i, response.body)
    end
  end

  test 'generic_error_messages=true hides suspended status' do
    with_settings('auth.generic_error_messages' => true) do
      @identity.update!(status: :suspended)

      post session_path, params: { identifier: 'enum-test@example.com', password: 'password1234' }

      assert_no_match(/suspended/i, response.body)
      assert_match(/Invalid credentials/i, response.body)
    end
  end

  # --- Password reset does not enumerate ---

  test 'password reset always returns success regardless of identifier existence' do
    # Existing identifier
    post password_resets_path, params: { identifier: 'enum-test@example.com' }
    existing_status = response.status

    # Non-existent identifier
    post password_resets_path, params: { identifier: 'nobody@example.com' }
    missing_status = response.status

    # Both should return the same response (redirect or success)
    assert_equal existing_status, missing_status,
      'Password reset must return same status for existing and non-existing identifiers'
  end

  # --- Timing consistency ---

  test 'login response time is similar for existing and non-existing identifiers' do
    # This test verifies the dummy bcrypt comparison is in place.
    # We measure multiple iterations to reduce noise.
    iterations = 3

    existing_times = iterations.times.map do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      post session_path, params: { identifier: 'enum-test@example.com', password: 'wrongpassword' }
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    missing_times = iterations.times.map do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      post session_path, params: { identifier: 'nonexistent-timing@example.com', password: 'wrongpassword' }
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    avg_existing = existing_times.sum / iterations
    avg_missing = missing_times.sum / iterations
    delta = (avg_existing - avg_missing).abs

    # In test env (bcrypt cost 4), delta should be very small.
    # Allow up to 200ms to account for test environment variability.
    assert delta < 0.2,
      "Timing delta between existing (#{avg_existing.round(3)}s) and non-existing (#{avg_missing.round(3)}s) " \
      "identifiers is #{delta.round(3)}s — should be < 0.2s"
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
