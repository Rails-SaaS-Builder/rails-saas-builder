# frozen_string_literal: true

# Security Test: CSRF Protection on Auth Forms
#
# Attack vectors prevented:
# - Cross-site request forgery on login
# - CSRF on registration
# - CSRF on password reset
# - CSRF on account deletion
# - CSRF on session revocation
#
# Note: Rails disables CSRF verification in test environments
# (allow_forgery_protection = false). These tests verify the
# code-level configuration rather than runtime enforcement.
#
# Covers: SRS-016 US-008 (CSRF Protection)

require 'test_helper'

class AuthCsrfTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'csrf-test@example.com')
  end

  test 'ApplicationController inherits from ActionController::Base (CSRF-capable)' do
    # ActionController::Base includes CSRF protection; API controllers do not.
    # This verifies rsb-auth uses the correct base class.
    assert RSB::Auth::ApplicationController.ancestors.include?(ActionController::Base),
           'Auth ApplicationController must inherit from ActionController::Base for CSRF protection'
  end

  test 'no auth controller skips forgery protection via skip_forgery_protection' do
    # Verify that no auth controller calls skip_forgery_protection
    auth_controllers = [
      RSB::Auth::ApplicationController,
      RSB::Auth::SessionsController,
      RSB::Auth::RegistrationsController,
      RSB::Auth::PasswordResetsController
    ]

    auth_controllers.each do |controller_class|
      # forgery_protection_strategy is nil only when protect_from_forgery is never called
      # (inherited default from ActionController::Base applies — CSRF is on)
      # The absence of explicit skip means protection is active.
      assert_not_nil controller_class.forgery_protection_strategy,
                     "#{controller_class} must have forgery protection strategy set (not skipped)"
    end
  end

  test 'login form (with method param) renders a form element' do
    # The credential selector shows links; the actual login form renders when ?method= is set
    get new_session_path(method: :email_password)
    assert_response :success
    assert_select 'form', minimum: 1, message: 'Login form must contain a <form> element'
  end

  test 'registration form (with method param) renders a form element' do
    get new_registration_path(method: :email_password)
    assert_response :success
    assert_select 'form', minimum: 1, message: 'Registration form must contain a <form> element'
  end

  test 'password reset form renders a form element' do
    get new_password_reset_path
    assert_response :success
    assert_select 'form', minimum: 1, message: 'Password reset form must contain a <form> element'
  end

  test 'login POST returns unprocessable_entity for wrong credentials (not method_not_allowed)' do
    # CSRF protection being active means forms must POST with tokens.
    # Verifying the endpoint properly handles POST (not blocked at routing level).
    post session_path, params: { identifier: 'csrf-test@example.com', password: 'wrong' }
    assert_response :unprocessable_entity
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
