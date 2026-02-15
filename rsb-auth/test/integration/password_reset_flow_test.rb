# frozen_string_literal: true

require 'test_helper'

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'resetflow@example.com', password: 'password1234')
  end

  test 'GET password_resets/new renders form' do
    get new_password_reset_path
    assert_response :success
    assert_select "input[name='identifier']"
  end

  test 'POST password_resets sends email and redirects' do
    assert_enqueued_emails 1 do
      post password_resets_path, params: { identifier: 'resetflow@example.com' }
    end

    assert_response :redirect
  end

  test 'GET password_resets/:token/edit renders form' do
    reset_token = @credential.password_reset_tokens.create!

    get edit_password_reset_path(token: reset_token.token)
    assert_response :success
    assert_select "input[name='password']"
  end

  test 'PATCH password_resets/:token resets password and redirects' do
    reset_token = @credential.password_reset_tokens.create!

    patch password_reset_path(token: reset_token.token), params: {
      token: reset_token.token,
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    }

    assert_response :redirect
    assert @credential.reload.authenticate('newpassword123')
  end

  test 'PATCH with invalid token shows error' do
    patch password_reset_path(token: 'invalid-token'), params: {
      token: 'invalid-token',
      password: 'newpassword123',
      password_confirmation: 'newpassword123'
    }

    assert_response :unprocessable_entity
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
