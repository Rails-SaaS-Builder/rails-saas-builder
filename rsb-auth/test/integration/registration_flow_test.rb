# frozen_string_literal: true

require 'test_helper'

class RegistrationFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
    Rails.cache.clear
  end

  test 'GET registration/new renders form' do
    get new_registration_path
    assert_response :success
    assert_select "input[name='identifier']"
    assert_select "input[name='password']"
    assert_select "input[name='password_confirmation']"
  end

  test 'POST registration with valid params creates identity + credential + session' do
    with_settings('auth.verification_required' => false) do
      assert_difference ['RSB::Auth::Identity.count', 'RSB::Auth::Credential.count'], 1 do
        post registration_path, params: {
          identifier: 'new@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        }
      end

      assert_response :redirect
      assert cookies[:rsb_session_token].present?
    end
  end

  test 'POST registration with invalid params re-renders with 422' do
    post registration_path, params: {
      identifier: '',
      password: 'short',
      password_confirmation: 'short'
    }

    assert_response :unprocessable_entity
  end

  test 'registration blocked when mode is disabled' do
    with_settings('auth.registration_mode' => 'disabled') do
      get new_registration_path
      assert_response :redirect
    end
  end

  test 'registration allowed when mode is open' do
    get new_registration_path
    assert_response :success
  end

  # --- invite_token handling ---

  test 'GET registration with invite_token stores in session' do
    invitation = create_test_invitation
    get new_registration_path(invite_token: invitation.token)

    assert_response :success
    # The hidden field should be in the form
    assert_match 'invite_token', response.body
  end

  test 'GET registration in invite_only mode without token shows message' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    get new_registration_path

    assert_response :success
    assert_match(/requires an invitation/i, response.body)
  end

  test 'GET registration in invite_only mode with valid token renders form' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    invitation = create_test_invitation
    get new_registration_path(invite_token: invitation.token)

    assert_response :success
    # Should render the registration form, not the "requires invitation" message
    assert_match 'invite_token', response.body
  end

  test 'POST registration with invite_token in invite_only mode creates identity' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    invitation = create_test_invitation

    post registration_path, params: {
      identifier: 'invited@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }

    assert_response :redirect
    invitation.reload
    assert_equal 1, invitation.uses_count
  end

  test 'POST registration with invite_token in open mode tracks invitation' do
    RSB::Settings.set('auth.registration_mode', 'open')
    invitation = create_test_invitation

    post registration_path, params: {
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }

    assert_response :redirect
    invitation.reload
    assert_equal 1, invitation.uses_count
  end

  test 'POST registration in invite_only mode without token returns error' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')

    post registration_path, params: {
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    }

    assert_response :unprocessable_entity
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
