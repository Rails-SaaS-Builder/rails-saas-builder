require "test_helper"

class RSB::Auth::Account::SessionsControllerTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
    @identity = RSB::Auth::Identity.create!(metadata: { "name" => "Test" })
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "sessions@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    post session_path, params: { identifier: "sessions@example.com", password: "password1234" }
    @current_session = @identity.sessions.reload.last

    # Create additional sessions for revocation tests
    @other_session = @identity.sessions.create!(
      ip_address: "10.0.0.1",
      user_agent: "OtherBrowser/1.0",
      last_active_at: Time.current
    )
    @another_session = @identity.sessions.create!(
      ip_address: "10.0.0.2",
      user_agent: "AnotherBrowser/2.0",
      last_active_at: Time.current
    )
  end

  # --- Authentication ---

  test "destroy requires authentication" do
    cookies.delete("rsb_session_token")
    delete account_session_path(@other_session)
    assert_response :redirect
  end

  test "destroy_all requires authentication" do
    cookies.delete("rsb_session_token")
    delete destroy_all_account_sessions_path
    assert_response :redirect
  end

  # --- destroy ---

  test "destroy revokes target session" do
    delete account_session_path(@other_session)
    assert_response :redirect
    assert_redirected_to account_path
    assert @other_session.reload.expired?
    assert_equal I18n.t("rsb.auth.account.session_revoked"), flash[:notice]
  end

  test "destroy for another identity's session returns 404" do
    other_identity = RSB::Auth::Identity.create!
    other_identity_session = other_identity.sessions.create!(
      ip_address: "192.168.1.1",
      user_agent: "Intruder/1.0",
      last_active_at: Time.current
    )
    delete account_session_path(other_identity_session)
    assert_response :not_found
  end

  # --- destroy_all ---

  test "destroy_all revokes all sessions except current" do
    delete destroy_all_account_sessions_path
    assert_response :redirect
    assert_redirected_to account_path

    # Other sessions are expired
    assert @other_session.reload.expired?
    assert @another_session.reload.expired?

    # Current session is still active
    refute @current_session.reload.expired?
  end

  test "destroy_all redirects to account with notice" do
    delete destroy_all_account_sessions_path
    assert_response :redirect
    assert_redirected_to account_path
    assert_equal I18n.t("rsb.auth.account.all_sessions_revoked"), flash[:notice]
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
