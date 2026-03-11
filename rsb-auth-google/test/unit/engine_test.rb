# frozen_string_literal: true

require 'test_helper'

class RSB::Auth::Google::EngineTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    register_all_credentials
  end

  test 'google credential type is registered in credential registry' do
    defn = RSB::Auth.credentials.find(:google)
    assert_not_nil defn, 'Google credential must be registered'
    assert_equal :google, defn.key
    assert_equal 'RSB::Auth::Google::Credential', defn.class_name
  end

  test 'google credential definition has correct attributes' do
    defn = RSB::Auth.credentials.find(:google)
    assert defn.authenticatable
    assert defn.registerable
    assert_equal 'Google', defn.label
    assert_equal 'google', defn.icon
    assert_not_nil defn.form_partial
    assert_not_nil defn.redirect_url
    assert_nil defn.admin_form_partial
  end

  test 'google credential has redirect_url pointing to OAuth endpoint' do
    defn = RSB::Auth.credentials.find(:google)
    assert_match %r{/auth/oauth/google}, defn.redirect_url
  end

  test 'google settings are registered and resolvable' do
    assert_equal '', RSB::Settings.get('auth.credentials.google.client_id')
    assert_equal '', RSB::Settings.get('auth.credentials.google.client_secret')
    assert_equal false, RSB::Settings.get('auth.credentials.google.auto_merge_by_email')
  end

  test 'per-credential settings are registered with correct Google defaults' do
    assert_equal true, RSB::Settings.get('auth.credentials.google.enabled')
    assert_equal false, RSB::Settings.get('auth.credentials.google.verification_required')
    assert_equal true, RSB::Settings.get('auth.credentials.google.auto_verify_on_signup')
    assert_equal true, RSB::Settings.get('auth.credentials.google.allow_login_unverified')
    assert_equal true, RSB::Settings.get('auth.credentials.google.registerable')
  end
end
