require "test_helper"

class RSB::Auth::AccountServiceDeletionTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth", password_min_length: 8, session_duration: 86_400)
    @identity = RSB::Auth::Identity.create!
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "delete-me@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    @session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )
    @service = RSB::Auth::AccountService.new
  end

  # --- delete_account: happy path ---

  test "delete_account with correct password succeeds" do
    result = @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert result.success?
    assert_empty result.errors
  end

  test "delete_account sets status to deleted" do
    @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert_equal "deleted", @identity.reload.status
  end

  test "delete_account sets deleted_at" do
    freeze_time do
      @service.delete_account(
        identity: @identity,
        password: "password1234",
        current_session: @session
      )

      assert_equal Time.current, @identity.reload.deleted_at
    end
  end

  test "delete_account revokes all active sessions" do
    other_session = @identity.sessions.create!(
      ip_address: "10.0.0.1",
      user_agent: "OtherBrowser/1.0",
      last_active_at: Time.current
    )

    @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert @session.reload.expired?
    assert other_session.reload.expired?
  end

  test "delete_account revokes all active credentials" do
    _second_credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "second@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert @credential.reload.revoked?
    assert @identity.credentials.where(identifier: "second@example.com").first.reload.revoked?
  end

  test "delete_account fires after_identity_deleted lifecycle hook" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_identity_deleted) { |identity| called_with = identity }
    end
    stub_name = "RSB::Auth::TestDeletedHandler"
    RSB::Auth.const_set(:TestDeletedHandler, handler_class)
    RSB::Auth.configuration.lifecycle_handler = stub_name

    @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert_equal @identity, called_with
  ensure
    RSB::Auth.configuration.lifecycle_handler = nil
    RSB::Auth.send(:remove_const, :TestDeletedHandler) if RSB::Auth.const_defined?(:TestDeletedHandler)
  end

  # --- delete_account: failure cases ---

  test "delete_account with wrong password fails" do
    result = @service.delete_account(
      identity: @identity,
      password: "wrongpassword",
      current_session: @session
    )

    assert_not result.success?
    assert_includes result.errors, "Current password is incorrect."
    assert_equal "active", @identity.reload.status
  end

  test "delete_account with no primary credential fails" do
    @credential.update_columns(revoked_at: Time.current)

    result = @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    assert_not result.success?
    assert_includes result.errors, "No active login method found. Contact support to delete your account."
    assert_equal "active", @identity.reload.status
  end

  # --- delete_account: transaction safety ---

  test "delete_account wraps changes in transaction" do
    # Simulate a failure during credential revocation by making revoke! raise
    # on the second credential after the first succeeds.
    _second_credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "second@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    call_count = 0
    original_revoke = RSB::Auth::Credential.instance_method(:revoke!)
    RSB::Auth::Credential.silence_redefinition_of_method(:revoke!)
    RSB::Auth::Credential.define_method(:revoke!) do
      call_count += 1
      raise ActiveRecord::ActiveRecordError, "simulated failure" if call_count == 2
      original_revoke.bind_call(self)
    end

    result = @service.delete_account(
      identity: @identity,
      password: "password1234",
      current_session: @session
    )

    # The transaction should have rolled back — identity should still be active
    assert_not result.success?
    assert_equal "active", @identity.reload.status
    assert_nil @identity.deleted_at
    # First credential revocation should have been rolled back too
    assert_not @credential.reload.revoked?
  ensure
    RSB::Auth::Credential.silence_redefinition_of_method(:revoke!)
    RSB::Auth::Credential.define_method(:revoke!, original_revoke)
  end
end
