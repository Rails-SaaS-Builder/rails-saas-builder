# frozen_string_literal: true

require 'test_helper'

class AuthHardeningPasswordResetTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @username_cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'recovery@example.com'
    )
  end

  test 'password reset by recovery_email sends email' do
    assert_enqueued_emails 1 do
      post password_resets_path, params: { identifier: 'recovery@example.com' }
    end
    assert_response :redirect
  end

  test 'password reset by username sends to recovery_email' do
    assert_enqueued_emails 1 do
      post password_resets_path, params: { identifier: 'testuser' }
    end
  end

  test 'password reset for username without recovery_email creates token but skips email' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser2',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    assert_no_enqueued_emails do
      post password_resets_path, params: { identifier: 'testuser2' }
    end
    assert_response :redirect
    assert cred.password_reset_tokens.any?
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
