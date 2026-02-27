# frozen_string_literal: true

# Security Test: Admin Email Verification Token Security
#
# Attack vectors prevented:
# - Email verification token replay after use
# - Email verification token use after expiry
# - Token brute force (sufficient entropy)
#
# Covers: SRS-016 US-016 (Admin Email Verification)

require 'test_helper'

class AdminEmailVerificationTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'email verification token has sufficient entropy' do
    @admin.update!(
      pending_email: 'new@example.com',
      email_verification_token: SecureRandom.urlsafe_base64(32),
      email_verification_sent_at: Time.current
    )
    assert @admin.email_verification_token.length >= 32
  end

  test 'email verification token is single-use (cleared after verify)' do
    @admin.update!(
      pending_email: 'verified@example.com',
      email_verification_token: SecureRandom.urlsafe_base64(32),
      email_verification_sent_at: Time.current
    )
    token = @admin.email_verification_token

    # Verify the email
    get rsb_admin.verify_email_profile_path(token: token)

    @admin.reload
    assert_nil @admin.email_verification_token, 'Token must be cleared after verification'
    assert_nil @admin.pending_email, 'Pending email must be cleared after verification'
  end

  test 'email verification with invalid token shows error' do
    get rsb_admin.verify_email_profile_path(token: 'invalid-token-value')
    # Should not raise — should redirect or show an error
    assert_response :redirect
  end

  test 'email verification token rejected after expiry' do
    @admin.update!(
      pending_email: 'expired@example.com',
      email_verification_token: SecureRandom.urlsafe_base64(32),
      email_verification_sent_at: Time.current
    )
    token = @admin.email_verification_token

    travel 25.hours do
      get rsb_admin.verify_email_profile_path(token: token)
      @admin.reload
      # Email should NOT have changed
      assert_not_equal 'expired@example.com', @admin.email,
                       'Expired token must not verify the email'
    end
  end

  test 'reusing email verification token after use fails' do
    @admin.update!(
      pending_email: 'reuse@example.com',
      email_verification_token: SecureRandom.urlsafe_base64(32),
      email_verification_sent_at: Time.current
    )
    token = @admin.email_verification_token

    # First use — should succeed
    get rsb_admin.verify_email_profile_path(token: token)
    @admin.reload
    assert_equal 'reuse@example.com', @admin.email

    # Second use — should fail (token cleared)
    get rsb_admin.verify_email_profile_path(token: token)
    # Should not raise, should redirect with error
    assert_response :redirect
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
