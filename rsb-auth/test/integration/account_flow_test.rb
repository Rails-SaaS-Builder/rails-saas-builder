# frozen_string_literal: true

require "test_helper"

# End-to-end integration tests for account management flows:
# view account, update metadata, incomplete redirect after login/registration,
# and settings-based disable.
class AccountFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
    # Disable verification for these tests (they don't test verification behavior)
    RSB::Settings.set("auth.credentials.email_password.verification_required", false)
    Rails.cache.clear
  end

  # --- Flow 1: View account page ---

  test "authenticated user views account page with credentials" do
    identity = create_test_identity
    create_test_credential(identity: identity)
    post session_path, params: { identifier: "test@example.com", password: "password1234" }

    get account_path
    assert_response :success
  end

  test "unauthenticated user is redirected to login" do
    get account_path
    assert_response :redirect
    assert_match %r{/auth/session/new}, response.location
  end

  # --- Flow 2: Update identity metadata ---

  test "user updates metadata via account form" do
    identity = RSB::Auth::Identity.create!(metadata: { "name" => "Old" })
    create_test_credential(identity: identity)
    post session_path, params: { identifier: "test@example.com", password: "password1234" }

    patch account_path, params: { identity: { metadata: { "name" => "New" } } }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    assert_equal({ "name" => "New" }, identity.reload.metadata)
  end

  # --- Flow 3: Redirect after login if incomplete ---

  test "login redirects to account when identity is incomplete" do
    identity = create_test_identity
    create_test_credential(identity: identity, email: "incomplete-login@example.com")

    concern = Module.new do
      extend ActiveSupport::Concern
      def complete?
        false
      end
    end

    with_identity_concerns(concern) do
      post session_path, params: {
        identifier: "incomplete-login@example.com",
        password: "password1234"
      }
    end

    assert_response :redirect
    assert_match %r{/auth/account}, response.location
  end

  test "login redirects to root when identity is complete" do
    identity = create_test_identity
    create_test_credential(identity: identity, email: "complete-login@example.com")

    post session_path, params: {
      identifier: "complete-login@example.com",
      password: "password1234"
    }

    assert_response :redirect
    refute_match %r{/auth/account\b}, response.location
  end

  # --- Flow 4: Redirect after registration if incomplete ---

  test "registration redirects to account when identity is incomplete" do
    with_settings("auth.verification_required" => false) do
      concern = Module.new do
        extend ActiveSupport::Concern
        def complete?
          false
        end
      end

      with_identity_concerns(concern) do
        post registration_path, params: {
          identifier: "newuser-incomplete@example.com",
          password: "password1234",
          password_confirmation: "password1234"
        }
      end

      assert_response :redirect
      assert_match %r{/auth/account}, response.location
    end
  end

  # --- Settings-based disable ---

  test "account page disabled via settings redirects away" do
    identity = create_test_identity
    create_test_credential(identity: identity)
    post session_path, params: { identifier: "test@example.com", password: "password1234" }

    with_settings("auth.account_enabled" => false) do
      get account_path
      assert_response :redirect
    end
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
