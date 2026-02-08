# frozen_string_literal: true

require "test_helper"

class AuthHardeningSettingsTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
  end

  # --- Per-credential settings exist after full boot ---

  test "per-credential settings are accessible via RSB::Settings.get" do
    assert_equal true, RSB::Settings.get("auth.credentials.email_password.verification_required")
    assert_equal false, RSB::Settings.get("auth.credentials.email_password.auto_verify_on_signup")
    assert_equal false, RSB::Settings.get("auth.credentials.email_password.allow_login_unverified")
    assert_equal true, RSB::Settings.get("auth.credentials.email_password.registerable")
  end

  test "username_password per-credential settings exist" do
    assert_equal true, RSB::Settings.get("auth.credentials.username_password.verification_required")
    assert_equal true, RSB::Settings.get("auth.credentials.username_password.registerable")
  end

  test "phone_password settings do not exist (unregistered)" do
    # When a setting is not registered, get() returns nil
    assert_nil RSB::Settings.get("auth.credentials.phone_password.enabled")
  end

  test "admin.require_two_factor setting is accessible" do
    assert_equal false, RSB::Settings.get("admin.require_two_factor")
  end

  # --- Global verification_required still works as fallback ---

  test "global auth.verification_required setting still exists" do
    assert_equal true, RSB::Settings.get("auth.verification_required")
  end
end
