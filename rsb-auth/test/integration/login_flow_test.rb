require "test_helper"

class LoginFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
    @identity = create_test_identity
    create_test_credential(identity: @identity, email: "login@example.com", password: "password1234")
  end

  test "GET session/new renders login form" do
    get new_session_path
    assert_response :success
    assert_select "input[name='identifier']"
    assert_select "input[name='password']"
  end

  test "POST session with valid creds creates session and sets cookie" do
    assert_difference "RSB::Auth::Session.count", 1 do
      post session_path, params: {
        identifier: "login@example.com",
        password: "password1234"
      }
    end

    assert_response :redirect
    assert cookies[:rsb_session_token].present?
  end

  test "POST session with wrong password re-renders with 422" do
    post session_path, params: {
      identifier: "login@example.com",
      password: "wrongpassword"
    }

    assert_response :unprocessable_entity
  end

  test "DELETE session revokes session and clears cookie" do
    # First sign in
    post session_path, params: {
      identifier: "login@example.com",
      password: "password1234"
    }
    assert cookies[:rsb_session_token].present?

    # Now sign out
    delete session_path
    assert_response :redirect
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
