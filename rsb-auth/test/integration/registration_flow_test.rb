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

  test 'registration blocked when mode is invite_only' do
    with_settings('auth.registration_mode' => 'invite_only') do
      get new_registration_path
      assert_response :redirect
    end
  end

  test 'registration allowed when mode is open' do
    get new_registration_path
    assert_response :success
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
