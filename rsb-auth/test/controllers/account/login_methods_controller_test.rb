require "test_helper"

class RSB::Auth::Account::LoginMethodsControllerTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
    @identity = RSB::Auth::Identity.create!(metadata: { "name" => "Test" })
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "methods@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    post session_path, params: { identifier: "methods@example.com", password: "password1234" }
    @session = @identity.sessions.reload.last
  end

  # --- Authentication ---

  test "show requires authentication" do
    cookies.delete("rsb_session_token")
    get account_login_method_path(@credential)
    assert_response :redirect
  end

  # --- show ---

  test "show renders credential detail" do
    get account_login_method_path(@credential)
    assert_response :success
    assert_response_includes "methods@example.com"
    assert_response_includes "Email Password"
  end

  test "show for another identity's credential returns 404" do
    other_identity = RSB::Auth::Identity.create!
    other_credential = other_identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "other@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    get account_login_method_path(other_credential)
    assert_response :not_found
  end

  test "show for revoked credential returns 404" do
    @credential.revoke!
    get account_login_method_path(@credential)
    assert_response :not_found
  end

  test "show hides remove button when only one active credential" do
    get account_login_method_path(@credential)
    assert_response :success
    refute_response_includes "Remove"
  end

  test "show shows remove button when multiple active credentials" do
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "second@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    get account_login_method_path(@credential)
    assert_response :success
    assert_response_includes "Remove"
  end

  # --- change_password ---

  test "change_password with correct current password succeeds" do
    patch password_account_login_method_path(@credential), params: {
      current_password: "password1234",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678"
    }
    assert_response :redirect
    assert_redirected_to account_login_method_path(@credential)
    assert @credential.reload.authenticate("newpassword5678")
    assert_equal I18n.t("rsb.auth.account.password_changed"), flash[:notice]
  end

  test "change_password with wrong current password fails" do
    patch password_account_login_method_path(@credential), params: {
      current_password: "wrongpassword",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678"
    }
    assert_response :unprocessable_entity
  end

  test "change_password is rate limited" do
    11.times do
      patch password_account_login_method_path(@credential), params: {
        current_password: "password1234",
        new_password: "newpassword5678",
        new_password_confirmation: "newpassword5678"
      }
    end
    assert_response :too_many_requests
  end

  # --- destroy ---

  test "destroy revokes credential when multiple exist" do
    second = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "second@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    delete account_login_method_path(second)
    assert_response :redirect
    assert_redirected_to account_path
    assert second.reload.revoked?
    assert_equal I18n.t("rsb.auth.account.login_method_removed"), flash[:notice]
  end

  test "destroy refuses to revoke last credential" do
    delete account_login_method_path(@credential)
    assert_response :redirect
    assert_redirected_to account_path
    refute @credential.reload.revoked?
    assert_equal I18n.t("rsb.auth.account.cannot_remove_last"), flash[:alert]
  end

  test "destroy for another identity's credential returns 404" do
    other_identity = RSB::Auth::Identity.create!
    other_credential = other_identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "other2@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    delete account_login_method_path(other_credential)
    assert_response :not_found
  end

  # --- resend_verification ---

  test "resend_verification sends verification" do
    post resend_verification_account_login_method_path(@credential)
    assert_response :redirect
    assert_redirected_to account_login_method_path(@credential)
    assert_equal I18n.t("rsb.auth.account.verification_sent"), flash[:notice]
  end

  test "resend_verification for already verified credential" do
    @credential.update!(verified_at: Time.current)
    post resend_verification_account_login_method_path(@credential)
    assert_response :redirect
    assert_redirected_to account_login_method_path(@credential)
    assert_equal I18n.t("rsb.auth.account.already_verified"), flash[:alert]
  end

  private

  def default_url_options
    { host: "localhost" }
  end

  def assert_response_includes(text)
    assert_includes response.body, text, "Expected response body to include '#{text}'"
  end

  def refute_response_includes(text)
    refute_includes response.body, text, "Expected response body NOT to include '#{text}'"
  end
end
