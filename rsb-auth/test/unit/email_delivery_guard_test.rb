# frozen_string_literal: true

require "test_helper"

class EmailDeliveryGuardTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings

    @identity = create_test_identity
  end

  test "send_verification! sends email when deliverable_email is present" do
    cred = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "user@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert_enqueued_emails 1 do
      cred.send_verification!
    end

    assert_not_nil cred.verification_token
    assert_not_nil cred.verification_sent_at
  end

  test "send_verification! sets token but skips email when no deliverable_email" do
    cred = @identity.credentials.create!(
      type: "RSB::Auth::Credential::UsernamePassword",
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert_no_enqueued_emails do
      cred.send_verification!
    end

    assert_not_nil cred.verification_token
    assert_not_nil cred.verification_sent_at
  end

  test "send_verification! sends to recovery_email for username credential" do
    cred = @identity.credentials.create!(
      type: "RSB::Auth::Credential::UsernamePassword",
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234",
      recovery_email: "recovery@example.com"
    )

    assert_enqueued_emails 1 do
      cred.send_verification!
    end
  end
end
