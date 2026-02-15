# frozen_string_literal: true

require 'test_helper'

class AuthLocaleSwitcherTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
  end

  test 'locale switcher hidden on login page when single locale' do
    get '/auth/session/new'
    assert_response :success
    refute_match 'rsb-locale-footer', response.body
  end

  test 'locale switcher visible on login page when multiple locales' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de fr] }
    get '/auth/session/new'
    assert_response :success
    assert_match 'rsb-locale-footer', response.body
    assert_match 'English', response.body
    assert_match 'Deutsch', response.body
    assert_match 'Français', response.body
  end

  test 'locale switcher visible on registration page when multiple locales' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    get '/auth/registration/new'
    assert_response :success
    assert_match 'rsb-locale-footer', response.body
  end

  test 'locale switcher visible on password reset page when multiple locales' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    get '/auth/password_resets/new'
    assert_response :success
    assert_match 'rsb-locale-footer', response.body
  end

  test 'current locale shown as plain text (not a link) on auth page' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    get '/auth/session/new'
    assert_response :success
    assert_match 'rsb-locale-current', response.body
  end

  test 'POST /rsb/locale from auth page sets cookie and redirects' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    post '/rsb/locale', params: { locale: 'de', redirect_to: '/auth/session/new' }
    assert_response :redirect
    assert_redirected_to '/auth/session/new'
    assert_match 'rsb_locale=de', response.headers['Set-Cookie']
  end

  test 'locale persists across auth pages via cookie' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    I18n.available_locales = %i[en de]
    post '/rsb/locale', params: { locale: 'de', redirect_to: '/auth/session/new' }
    get '/auth/registration/new', headers: { 'HTTP_COOKIE' => 'rsb_locale=de' }
    assert_response :success
  ensure
    I18n.available_locales = [:en]
  end

  test 'locale switcher visible on account page when multiple locales' do
    RSB::Settings.configure { |c| c.available_locales = %w[en de] }
    identity = RSB::Auth::Identity.create!(status: 'active')
    RSB::Auth::Credential::EmailPassword.create!(
      identity: identity,
      identifier: 'test@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      verified_at: Time.current
    )
    post '/auth/session', params: {
      identifier: 'test@example.com',
      password: 'password1234',
      credential_type: 'email_password'
    }
    get '/auth/account'
    assert_response :success
    assert_match 'rsb-locale-footer', response.body
  end
end
