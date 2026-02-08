# frozen_string_literal: true

require "test_helper"

class PasswordResetServiceRecoveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings

    @identity = create_test_identity
  end

  test "finds credential by recovery_email and sends reset email" do
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::UsernamePassword",
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234",
      recovery_email: "recovery@example.com"
    )

    assert_enqueued_emails 1 do
      result = RSB::Auth::PasswordResetService.new.request_reset("recovery@example.com")
      assert result.success?
    end
  end

  test "finds credential by identifier (username) and sends to recovery_email" do
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::UsernamePassword",
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234",
      recovery_email: "recovery@example.com"
    )

    assert_enqueued_emails 1 do
      result = RSB::Auth::PasswordResetService.new.request_reset("testuser")
      assert result.success?
    end
  end

  test "username credential without recovery_email creates token but skips email" do
    cred = @identity.credentials.create!(
      type: "RSB::Auth::Credential::UsernamePassword",
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert_no_enqueued_emails do
      result = RSB::Auth::PasswordResetService.new.request_reset("testuser")
      assert result.success?
    end

    # Token should still be created
    assert cred.password_reset_tokens.any?
  end

  test "email credential sends to identifier as before" do
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "user@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert_enqueued_emails 1 do
      result = RSB::Auth::PasswordResetService.new.request_reset("user@example.com")
      assert result.success?
    end
  end

  test "non-existent identifier returns success (safe failure)" do
    result = RSB::Auth::PasswordResetService.new.request_reset("nobody@example.com")
    assert result.success?
  end
end
