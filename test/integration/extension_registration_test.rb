# frozen_string_literal: true

require 'test_helper'

class ExtensionRegistrationTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    register_all_credentials
  end

  test 'credential registry has built-in types' do
    keys = RSB::Auth.credentials.keys
    assert_includes keys, :email_password
    assert_includes keys, :username_password
  end

  test 'credential definitions are valid' do
    RSB::Auth.credentials.all.each do |defn|
      assert defn.valid?, "Credential definition #{defn.key} should be valid"
      assert defn.class_name.present?, "Credential definition #{defn.key} should have a class_name"
    end
  end

  test 'settings schemas are valid for all gems' do
    assert RSB::Auth.settings_schema.valid?, 'Auth settings schema should be valid'
    assert RSB::Entitlements.settings_schema.valid?, 'Entitlements settings schema should be valid'
    assert RSB::Admin.settings_schema.valid?, 'Admin settings schema should be valid'
  end

  test 'Subject concern works on Identity (cross-gem integration)' do
    identity = RSB::Auth::Identity.create!(status: 'active')
    assert identity.respond_to?(:active_subscription)
    assert identity.respond_to?(:entitled_to?)
    assert identity.respond_to?(:consume!)
    assert identity.respond_to?(:grant_for)
  end

  test 'Subject concern works on arbitrary models (Organization)' do
    org = Organization.create!(name: 'Test Corp')
    assert org.respond_to?(:active_subscription)
    assert org.respond_to?(:entitled_to?)
    assert org.respond_to?(:consume!)
    assert org.respond_to?(:grant_for)
  end

  test 'RSB::Entitlements does not expose v0 providers API' do
    refute RSB::Entitlements.respond_to?(:providers),
           'v1 must not expose .providers'
    refute RSB::Entitlements.respond_to?(:configure),
           'v1 must not expose .configure'
  end
end
