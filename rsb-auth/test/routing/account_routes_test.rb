# frozen_string_literal: true

require 'test_helper'

class AccountRoutesTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers
  include RSB::Auth::TestHelper

  setup do
    register_auth_settings
    register_auth_credentials
  end

  # --- New routes exist (assert_recognizes uses full path with mount prefix) ---

  test 'GET /auth/account routes to account#show' do
    assert_recognizes(
      { controller: 'rsb/auth/account', action: 'show' },
      { path: '/auth/account', method: :get }
    )
  end

  test 'PATCH /auth/account routes to account#update' do
    assert_recognizes(
      { controller: 'rsb/auth/account', action: 'update' },
      { path: '/auth/account', method: :patch }
    )
  end

  test 'GET /auth/account/confirm_destroy routes to account#confirm_destroy' do
    assert_recognizes(
      { controller: 'rsb/auth/account', action: 'confirm_destroy' },
      { path: '/auth/account/confirm_destroy', method: :get }
    )
  end

  test 'DELETE /auth/account routes to account#destroy' do
    assert_recognizes(
      { controller: 'rsb/auth/account', action: 'destroy' },
      { path: '/auth/account', method: :delete }
    )
  end

  test 'GET /auth/account/login_methods/:id routes to account/login_methods#show' do
    assert_recognizes(
      { controller: 'rsb/auth/account/login_methods', action: 'show', id: '1' },
      { path: '/auth/account/login_methods/1', method: :get }
    )
  end

  test 'PATCH /auth/account/login_methods/:id/password routes to account/login_methods#change_password' do
    assert_recognizes(
      { controller: 'rsb/auth/account/login_methods', action: 'change_password', id: '1' },
      { path: '/auth/account/login_methods/1/password', method: :patch }
    )
  end

  test 'DELETE /auth/account/login_methods/:id routes to account/login_methods#destroy' do
    assert_recognizes(
      { controller: 'rsb/auth/account/login_methods', action: 'destroy', id: '1' },
      { path: '/auth/account/login_methods/1', method: :delete }
    )
  end

  test 'POST /auth/account/login_methods/:id/resend_verification routes correctly' do
    assert_recognizes(
      { controller: 'rsb/auth/account/login_methods', action: 'resend_verification', id: '1' },
      { path: '/auth/account/login_methods/1/resend_verification', method: :post }
    )
  end

  test 'DELETE /auth/account/sessions/:id routes to account/sessions#destroy' do
    assert_recognizes(
      { controller: 'rsb/auth/account/sessions', action: 'destroy', id: '1' },
      { path: '/auth/account/sessions/1', method: :delete }
    )
  end

  test 'DELETE /auth/account/sessions routes to account/sessions#destroy_all' do
    assert_recognizes(
      { controller: 'rsb/auth/account/sessions', action: 'destroy_all' },
      { path: '/auth/account/sessions', method: :delete }
    )
  end

  # --- Old routes are gone ---

  test 'old sessions_management route does not exist' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/auth/sessions_management', method: :get)
    end
  end

  test 'old account/edit route does not exist' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/auth/account/edit', method: :get)
    end
  end

  test 'old account/password route does not exist' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path('/auth/account/password', method: :patch)
    end
  end
end
