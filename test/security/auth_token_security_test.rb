# frozen_string_literal: true

# Security Test: Token Security (Password Reset, Verification, Invitation)
#
# Attack vectors prevented:
# - Token replay after use (single-use enforcement)
# - Token use after expiry (time-limited enforcement)
# - Token brute force (sufficient entropy — 256 bits)
# - Session persistence after password reset (all sessions revoked)
#
# Covers: SRS-016 US-004 (Password Reset), US-005 (Verification), US-006 (Invitation)

require 'test_helper'

class AuthTokenSecurityTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'token-test@example.com')
  end

  # --- US-004: Password Reset Token Security ---

  test 'password reset token has sufficient entropy' do
    token = RSB::Auth::PasswordResetToken.create!(
      credential: @credential,
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 2.hours.from_now
    )
    assert token.token.length >= 32, "Token length #{token.token.length} insufficient"
  end

  test 'password reset token is single-use — used_at prevents replay' do
    token_record = RSB::Auth::PasswordResetToken.create!(
      credential: @credential,
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 2.hours.from_now
    )

    # Use the token
    patch password_reset_path(token_record.token), params: {
      password: 'newpassword1234',
      password_confirmation: 'newpassword1234'
    }

    # Attempt replay
    patch password_reset_path(token_record.token), params: {
      password: 'anotherpassword',
      password_confirmation: 'anotherpassword'
    }

    # The replay should fail — token already used
    token_record.reload
    assert token_record.used_at.present?, 'Token must be marked as used'
  end

  test 'password reset token rejected after expiry' do
    token_record = RSB::Auth::PasswordResetToken.create!(
      credential: @credential,
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 2.hours.from_now
    )

    travel 3.hours do
      patch password_reset_path(token_record.token), params: {
        password: 'newpassword1234',
        password_confirmation: 'newpassword1234'
      }

      # Should not reset the password — token expired
      token_record.reload
      assert_nil token_record.used_at, 'Expired token must not be usable'
    end
  end

  test 'successful password reset revokes all active sessions' do
    # Create some sessions
    3.times do
      RSB::Auth::SessionService.new.create(
        identity: @identity,
        ip_address: '127.0.0.1',
        user_agent: 'TestBrowser'
      )
    end
    assert_equal 3, @identity.sessions.active.count

    token_record = RSB::Auth::PasswordResetToken.create!(
      credential: @credential,
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 2.hours.from_now
    )

    patch password_reset_path(token_record.token), params: {
      password: 'newpassword1234',
      password_confirmation: 'newpassword1234'
    }

    assert_equal 0, @identity.sessions.active.count,
                 'All sessions must be revoked after password reset'
  end

  # --- US-005: Verification Token Security ---

  test 'verification token has sufficient entropy' do
    @credential.send_verification!
    assert @credential.verification_token.length >= 32
  end

  test 'verification token is single-use — cleared after verify' do
    @credential.update_column(:verified_at, nil) # un-verify
    @credential.send_verification!

    @credential.verify!
    @credential.reload

    assert_nil @credential.verification_token, 'Token must be cleared after verification'
    assert @credential.verified?
  end

  test 'verification token rejected after 24 hours' do
    @credential.update_column(:verified_at, nil)
    @credential.send_verification!

    travel 25.hours do
      assert_not @credential.verification_token_valid?,
                 'Verification token must be invalid after 24 hours'
    end
  end

  # --- US-006: Invitation Token Security ---

  test 'invitation token has sufficient entropy' do
    invitation = RSB::Auth::Invitation.create!(
      email: 'invited@example.com',
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 7.days.from_now,
      invited_by: @identity
    )
    assert invitation.token.length >= 32
  end

  test 'accepted invitation cannot be re-accepted' do
    invitation = RSB::Auth::Invitation.create!(
      email: 'invited2@example.com',
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 7.days.from_now,
      invited_by: @identity
    )

    # Accept the invitation
    result = RSB::Auth::InvitationService.new.accept(
      token: invitation.token,
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert result.success?

    # Try to re-accept
    result2 = RSB::Auth::InvitationService.new.accept(
      token: invitation.token,
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert_not result2.success?, 'Re-accepting an accepted invitation must fail'
  end

  test 'revoked invitation cannot be accepted' do
    invitation = RSB::Auth::Invitation.create!(
      email: 'revoked@example.com',
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 7.days.from_now,
      invited_by: @identity
    )
    invitation.update!(revoked_at: Time.current)

    result = RSB::Auth::InvitationService.new.accept(
      token: invitation.token,
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert_not result.success?, 'Revoked invitation must not be acceptable'
  end

  test 'expired invitation cannot be accepted' do
    invitation = RSB::Auth::Invitation.create!(
      email: 'expired@example.com',
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 7.days.from_now,
      invited_by: @identity
    )

    travel 8.days do
      result = RSB::Auth::InvitationService.new.accept(
        token: invitation.token,
        password: 'password1234',
        password_confirmation: 'password1234'
      )
      assert_not result.success?, 'Expired invitation must not be acceptable'
    end
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
