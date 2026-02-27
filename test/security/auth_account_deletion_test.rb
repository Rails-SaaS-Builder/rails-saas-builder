# frozen_string_literal: true

# Security Test: Account Deletion Completeness
#
# Attack vectors prevented:
# - Session persistence after account deletion
# - Credential reuse after account deletion
# - Unauthorized account deletion (requires password)
#
# Covers: SRS-016 US-009 (Account Deletion)

require 'test_helper'

class AuthAccountDeletionTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'delete-test@example.com')
    @session = RSB::Auth::SessionService.new.create(
      identity: @identity,
      ip_address: '127.0.0.1',
      user_agent: 'TestBrowser'
    )
  end

  test 'account deletion revokes all sessions' do
    # Create additional sessions
    2.times do
      RSB::Auth::SessionService.new.create(
        identity: @identity,
        ip_address: '127.0.0.1',
        user_agent: 'TestBrowser'
      )
    end
    assert_equal 3, @identity.sessions.active.count

    # Delete account via service
    result = RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'password1234',
      current_session: @session
    )

    assert result.success?
    assert_equal 0, @identity.sessions.active.count,
                 'All sessions must be revoked after account deletion'
  end

  test 'account deletion revokes all credentials' do
    result = RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'password1234',
      current_session: @session
    )

    assert result.success?
    assert_equal 0, @identity.credentials.active.count,
                 'All credentials must be revoked after deletion'
  end

  test 'account deletion sets identity status to deleted' do
    RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'password1234',
      current_session: @session
    )

    @identity.reload
    assert @identity.deleted?, 'Identity status must be "deleted"'
  end

  test 'login with deleted account credentials fails' do
    RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'password1234',
      current_session: @session
    )

    result = RSB::Auth::AuthenticationService.new.call(
      identifier: 'delete-test@example.com',
      password: 'password1234'
    )

    assert_not result.success?
  end

  test 'old session token fails after account deletion' do
    token = @session.token

    RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'password1234',
      current_session: @session
    )

    found = RSB::Auth::SessionService.new.find_by_token(token)
    assert_nil found, 'Old session token must not authenticate after deletion'
  end

  test 'account deletion requires password confirmation' do
    result = RSB::Auth::AccountService.new.delete_account(
      identity: @identity,
      password: 'wrong_password',
      current_session: @session
    )

    assert_not result.success?, 'Deletion must require correct password'
    @identity.reload
    assert_not @identity.deleted?, 'Identity must not be deleted with wrong password'
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
