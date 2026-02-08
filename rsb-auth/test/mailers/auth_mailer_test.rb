require "test_helper"

class RSB::Auth::AuthMailerTest < ActionMailer::TestCase
  setup do
    register_auth_settings
    @identity = RSB::Auth::Identity.create!
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "mailer@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
  end

  test "verification email" do
    @credential.update_columns(
      verification_token: "test-verification-token",
      verification_sent_at: Time.current
    )

    email = RSB::Auth::AuthMailer.verification(@credential)
    assert_equal ["mailer@example.com"], email.to
    assert_equal "Verify your email address", email.subject
    assert_match "test-verification-token", email.body.encoded
  end

  test "password_reset email" do
    reset_token = @credential.password_reset_tokens.create!

    email = RSB::Auth::AuthMailer.password_reset(@credential, reset_token)
    assert_equal ["mailer@example.com"], email.to
    assert_equal "Reset your password", email.subject
    assert_match reset_token.token, email.body.encoded
  end

  test "invitation email" do
    invitation = RSB::Auth::Invitation.create!(email: "invited@example.com")

    email = RSB::Auth::AuthMailer.invitation(invitation)
    assert_equal ["invited@example.com"], email.to
    assert_equal "You've been invited", email.subject
    assert_match invitation.token, email.body.encoded
  end
end
