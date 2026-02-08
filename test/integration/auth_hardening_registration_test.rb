# frozen_string_literal: true

require "test_helper"

class AuthHardeningRegistrationTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear
  end

  test "email registration with default settings sends verification" do
    assert_enqueued_emails 1 do
      post registration_path, params: {
        identifier: "user@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: "email_password"
      }
    end

    cred = RSB::Auth::Credential.last
    assert_not_nil cred.verification_token
  end

  test "email registration with auto_verify_on_signup skips email" do
    RSB::Settings.set("auth.credentials.email_password.verification_required", false)
    RSB::Settings.set("auth.credentials.email_password.auto_verify_on_signup", true)

    assert_no_enqueued_emails do
      post registration_path, params: {
        identifier: "user@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: "email_password"
      }
    end

    cred = RSB::Auth::Credential.last
    assert_not_nil cred.verified_at
  end

  test "username registration with recovery_email sends verification" do
    assert_enqueued_emails 1 do
      post registration_path, params: {
        identifier: "testuser",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: "username_password",
        recovery_email: "recovery@example.com"
      }
    end

    cred = RSB::Auth::Credential.last
    assert_equal "recovery@example.com", cred.recovery_email
  end

  test "registration blocked when registerable is false" do
    RSB::Settings.set("auth.credentials.email_password.registerable", false)

    assert_no_difference "RSB::Auth::Credential.count" do
      post registration_path, params: {
        identifier: "user@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: "email_password"
      }
    end
  end

  test "login with unverified credential blocked by default" do
    # Create an unverified credential directly (no verified_at)
    identity = RSB::Auth::Identity.create!
    identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "unverified@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    # verification_required is true by default — login should be blocked
    post session_path, params: {
      identifier: "unverified@example.com",
      password: "password1234"
    }

    # Should be blocked — unverified
    refute cookies[:rsb_session_token].present?
  end

  test "login with allow_login_unverified succeeds" do
    RSB::Settings.set("auth.credentials.email_password.allow_login_unverified", true)

    post registration_path, params: {
      identifier: "user@example.com",
      password: "password1234",
      password_confirmation: "password1234",
      credential_type: "email_password"
    }

    post session_path, params: {
      identifier: "user@example.com",
      password: "password1234"
    }

    assert_response :redirect
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
