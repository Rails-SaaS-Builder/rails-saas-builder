require "test_helper"

class RSB::Auth::RegistrationServiceTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth",
      password_min_length: 8,
      session_duration: 86_400,
      registration_mode: "open",
      login_identifier: "email",
      verification_required: false,
      lockout_threshold: 5,
      lockout_duration: 900
    )
    RSB::Auth.credentials.register(
      RSB::Auth::CredentialDefinition.new(
        key: :email_password,
        class_name: "RSB::Auth::Credential::EmailPassword"
      )
    )
    # Register all per-credential settings (enabled, registerable, verification_required, etc.)
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
  end

  test "creates identity and credential on success" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "newuser@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert result.success?
    assert_instance_of RSB::Auth::Identity, result.identity
    assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
    assert_equal "newuser@example.com", result.credential.identifier
  end

  test "returns failure when registration is disabled" do
    with_settings("auth.registration_mode" => "disabled") do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: "test@example.com",
        password: "password1234",
        password_confirmation: "password1234"
      )

      assert_not result.success?
      assert_includes result.errors, "Registration is disabled."
    end
  end

  test "returns failure when registration is invite_only" do
    with_settings("auth.registration_mode" => "invite_only") do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: "test@example.com",
        password: "password1234",
        password_confirmation: "password1234"
      )

      assert_not result.success?
      assert_includes result.errors, "Registration is invite-only."
    end
  end

  test "returns failure for invalid params" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "",
      password: "short",
      password_confirmation: "short"
    )

    assert_not result.success?
    assert result.errors.any?
  end

  test "uses credential registry to resolve credential type" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "registry-test@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    assert result.success?
    assert_equal "RSB::Auth::Credential::EmailPassword", result.credential.type
  end

  test "allows registration with identifier that was previously revoked" do
    register_auth_credentials

    # Create and revoke a credential
    identity = RSB::Auth::Identity.create!
    cred = identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "reused@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    cred.update_columns(revoked_at: Time.current)

    # Register with the same identifier
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "reused@example.com",
      password: "newpassword5678",
      password_confirmation: "newpassword5678"
    )

    assert result.success?
    assert result.credential.persisted?
    assert_nil result.credential.revoked_at

    # Old revoked credential still exists
    assert_equal 2, RSB::Auth::Credential.where(identifier: "reused@example.com").count
  end

  # --- Explicit credential_type parameter ---

  test "creates credential with explicit credential_type" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "explicit@example.com",
      password: "password1234",
      password_confirmation: "password1234",
      credential_type: :email_password
    )
    assert result.success?
    assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
  end

  test "returns failure when credential_type is disabled" do
    with_settings("auth.credentials.email_password.enabled" => false) do
      result = RSB::Auth::RegistrationService.new.call(
        identifier: "disabled@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: :email_password
      )
      assert_not result.success?
      assert_includes result.errors, "This registration method is not available."
    end
  end

  test "returns failure when credential_type is unknown" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "unknown@example.com",
      password: "password1234",
      password_confirmation: "password1234",
      credential_type: :nonexistent_type
    )
    assert_not result.success?
    assert_includes result.errors, "This registration method is not available."
  end

  test "backward compat: without credential_type falls back to login_identifier" do
    result = RSB::Auth::RegistrationService.new.call(
      identifier: "fallback@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    assert result.success?
    assert_instance_of RSB::Auth::Credential::EmailPassword, result.credential
  end
end
