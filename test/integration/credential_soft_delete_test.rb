# frozen_string_literal: true

require 'test_helper'

class CredentialSoftDeleteTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    register_all_credentials
    Rails.cache.clear

    @admin = create_test_admin!(superadmin: true)
    @identity = RSB::Auth::Identity.create!(status: 'active')
    @credential = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'victim@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    @credential.update_column(:verified_at, Time.current)
  end

  # --- Flow 1: Admin revokes credential, user can no longer log in ---

  test 'admin revokes credential and user cannot authenticate' do
    sign_in_admin(@admin)
    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }
    assert_response :redirect
    assert @credential.reload.revoked?

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'victim@example.com',
      password: 'password1234'
    )
    assert_not result.success?
    assert_equal 'Invalid credentials.', result.error
  end

  # --- Flow 2: Admin restores credential, user can log in again ---

  test 'admin restores credential and user can authenticate again' do
    @credential.update_columns(revoked_at: Time.current)

    sign_in_admin(@admin)
    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }
    assert_response :redirect
    assert_not @credential.reload.revoked?

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'victim@example.com',
      password: 'password1234'
    )
    assert result.success?
  end

  # --- Flow 3: Restore blocked when active duplicate exists ---

  test 'admin cannot restore when active duplicate exists' do
    @credential.update_columns(revoked_at: Time.current)

    other_identity = RSB::Auth::Identity.create!
    other_identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'victim@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    sign_in_admin(@admin)
    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }
    assert_response :redirect
    assert @credential.reload.revoked?
  end

  # --- Flow 4: Registration re-uses revoked identifier ---

  test 'new user can register with previously revoked identifier' do
    @credential.revoke!

    result = with_settings('auth.verification_required' => false) do
      RSB::Auth::RegistrationService.new.call(
        identifier: 'victim@example.com',
        password: 'newpassword5678',
        password_confirmation: 'newpassword5678'
      )
    end

    assert result.success?
    assert_not_equal @identity.id, result.identity.id
    assert_nil result.credential.revoked_at

    assert @credential.reload.revoked?
    assert_equal 2, RSB::Auth::Credential.where(identifier: 'victim@example.com').count
  end

  # --- Flow 5: primary_credential skips revoked ---

  test 'primary_credential and primary_identifier skip revoked credentials' do
    @credential.revoke!
    assert_nil @identity.reload.primary_credential
    assert_nil @identity.primary_identifier

    new_cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'new@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert_equal new_cred, @identity.primary_credential
    assert_equal 'new@example.com', @identity.primary_identifier
  end

  # --- Flow 6: identity.credentials returns all ---

  test 'identity.credentials returns both active and revoked' do
    @credential.revoke!
    new_cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'new@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    all_creds = @identity.credentials
    assert_equal 2, all_creds.count
    assert_includes all_creds, @credential
    assert_includes all_creds, new_cred
  end

  # --- Flow 7: Lifecycle handlers fire ---

  test 'lifecycle handler fires on revoke and restore' do
    revoked_credentials = []
    restored_credentials = []

    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_credential_revoked) { |c| revoked_credentials << c }
      define_method(:after_credential_restored) { |c| restored_credentials << c }
    end

    RSB::Auth.const_set(:TestSoftDeleteHandler, handler_class)
    RSB::Auth.configuration.lifecycle_handler = 'RSB::Auth::TestSoftDeleteHandler'

    @credential.revoke!
    assert_equal [@credential], revoked_credentials

    @credential.restore!
    assert_equal [@credential], restored_credentials
  ensure
    RSB::Auth.configuration.lifecycle_handler = nil
    RSB::Auth.send(:remove_const, :TestSoftDeleteHandler) if RSB::Auth.const_defined?(:TestSoftDeleteHandler)
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
