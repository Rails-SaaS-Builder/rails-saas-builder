# frozen_string_literal: true

require 'test_helper'

class CredentialSelectorLoginTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    # Register per-credential enabled settings
    RSB::Settings.registry.define('auth') do
      setting :"credentials.email_password.enabled",
              type: :boolean, default: true,
              group: 'Credential Types', description: 'Enable Email & Password'
      setting :"credentials.username_password.enabled",
              type: :boolean, default: true,
              group: 'Credential Types', description: 'Enable Username & Password'
    end
    register_all_auth_credentials
    Rails.cache.clear

    @identity = create_test_identity
    create_test_credential(identity: @identity, email: 'login@example.com', password: 'password1234')
  end

  # --- Selector rendering ---

  test 'login page shows selector when multiple credential types are enabled' do
    get new_session_path
    assert_response :success
    assert_match 'Email &amp; Password', response.body
    assert_match 'Username &amp; Password', response.body
  end

  test 'login page renders form directly when only one type is enabled' do
    with_settings(
      'auth.credentials.username_password.enabled' => false
    ) do
      get new_session_path
      assert_response :success
      # Should show the form directly, not the selector
      assert_select "input[name='identifier']"
      assert_select "input[name='password']"
      # Should NOT show the selector buttons
      refute_match 'Username &amp; Password', response.body
    end
  end

  test "login page with ?method= renders that type's form" do
    get new_session_path(method: 'email_password')
    assert_response :success
    assert_select "input[name='identifier']"
    assert_select "input[name='password']"
    assert_select "input[name='credential_type'][value='email_password']", visible: :all
  end

  test 'login page with ?method= for username type renders username form' do
    get new_session_path(method: 'username_password')
    assert_response :success
    assert_select "input[name='identifier']"
    assert_select "input[name='password']"
    assert_select "input[name='credential_type'][value='username_password']", visible: :all
  end

  test 'login page with unknown ?method= falls back to selector' do
    get new_session_path(method: 'nonexistent')
    assert_response :success
    # Should show selector, not a form
    assert_match 'Email &amp; Password', response.body
  end

  test 'login page with disabled ?method= falls back to remaining enabled type' do
    with_settings('auth.credentials.email_password.enabled' => false) do
      get new_session_path(method: 'email_password')
      assert_response :success
      # Should fall back to username form since it's the only enabled type
      assert_select "input[name='credential_type'][value='username_password']", visible: :all
      assert_select "input[name='identifier']"
    end
  end

  test 'login page with zero enabled types shows error' do
    with_settings(
      'auth.credentials.email_password.enabled' => false,
      'auth.credentials.username_password.enabled' => false
    ) do
      get new_session_path
      assert_response :success
      assert_match(/no.*sign-in.*method/i, response.body)
    end
  end

  # --- Form submission ---

  test 'login with credential_type authenticates successfully' do
    post session_path, params: {
      identifier: 'login@example.com',
      password: 'password1234',
      credential_type: 'email_password'
    }
    assert_response :redirect
    assert cookies[:rsb_session_token].present?
  end

  test 'login with disabled credential_type is rejected' do
    with_settings('auth.credentials.email_password.enabled' => false) do
      post session_path, params: {
        identifier: 'login@example.com',
        password: 'password1234',
        credential_type: 'email_password'
      }
      assert_response :unprocessable_entity
      assert_match 'not available', response.body
    end
  end

  test 'login with wrong password re-renders with method preserved' do
    post session_path, params: {
      identifier: 'login@example.com',
      password: 'wrongpassword',
      credential_type: 'email_password'
    }
    assert_response :unprocessable_entity
    # Form should still be rendered for email_password (not reset to selector)
    assert_select "input[name='credential_type'][value='email_password']", visible: :all
  end

  test 'login without credential_type still works (backward compat)' do
    # When only one type is enabled, credential_type param is optional
    with_settings(
      'auth.credentials.username_password.enabled' => false
    ) do
      post session_path, params: {
        identifier: 'login@example.com',
        password: 'password1234'
      }
      assert_response :redirect
      assert cookies[:rsb_session_token].present?
    end
  end

  # --- Other sign-in methods link ---

  test 'form page has link back to selector' do
    get new_session_path(method: 'email_password')
    assert_response :success
    assert_select "a[href='#{new_session_path}']"
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
