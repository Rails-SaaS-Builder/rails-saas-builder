require "test_helper"

class CredentialSelectorSignupTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_all_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
    Rails.cache.clear
  end

  # --- Selector rendering ---

  test "signup page shows selector when multiple credential types are enabled" do
    get new_registration_path
    assert_response :success
    assert_match "Email &amp; Password", response.body
    assert_match "Username &amp; Password", response.body
  end

  test "signup page renders form directly when only one type is enabled" do
    with_settings(
      "auth.credentials.username_password.enabled" => false
    ) do
      get new_registration_path
      assert_response :success
      assert_select "input[name='identifier']"
      assert_select "input[name='password']"
      assert_select "input[name='password_confirmation']"
    end
  end

  test "signup page with ?method= renders that type's form" do
    get new_registration_path(method: "email_password")
    assert_response :success
    assert_select "input[name='identifier']"
    assert_select "input[name='credential_type'][value='email_password']", visible: :all
  end

  # --- Form submission ---

  test "signup with credential_type creates identity and credential" do
    with_settings("auth.verification_required" => false) do
      assert_difference ["RSB::Auth::Identity.count", "RSB::Auth::Credential.count"], 1 do
        post registration_path, params: {
          identifier: "new@example.com",
          password: "password1234",
          password_confirmation: "password1234",
          credential_type: "email_password"
        }
      end
      assert_response :redirect
      assert cookies[:rsb_session_token].present?
    end
  end

  test "signup with disabled credential_type is rejected" do
    with_settings("auth.credentials.email_password.enabled" => false) do
      post registration_path, params: {
        identifier: "disabled@example.com",
        password: "password1234",
        password_confirmation: "password1234",
        credential_type: "email_password"
      }
      assert_response :unprocessable_entity
      assert_match "not available", response.body
    end
  end

  test "signup registration mode still respected" do
    with_settings("auth.registration_mode" => "disabled") do
      get new_registration_path
      assert_response :redirect
    end
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
