require "test_helper"

class RSB::Auth::AccountServiceRestoreTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth", password_min_length: 8, session_duration: 86_400)
    @identity = RSB::Auth::Identity.create!(status: :deleted, deleted_at: Time.current)
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "restore-me@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    # Simulate credential was revoked during deletion
    @credential.update_columns(revoked_at: Time.current)
    @service = RSB::Auth::AccountService.new
  end

  test "restore_account sets status to active" do
    result = @service.restore_account(identity: @identity)

    assert result.success?
    assert_equal "active", @identity.reload.status
  end

  test "restore_account clears deleted_at" do
    result = @service.restore_account(identity: @identity)

    assert result.success?
    assert_nil @identity.reload.deleted_at
  end

  test "restore_account returns identity in result" do
    result = @service.restore_account(identity: @identity)

    assert_equal @identity, result.identity
  end

  test "restore_account fires after_identity_restored lifecycle hook" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_identity_restored) { |identity| called_with = identity }
    end
    stub_name = "RSB::Auth::TestRestoredIdentityHandler"
    RSB::Auth.const_set(:TestRestoredIdentityHandler, handler_class)
    RSB::Auth.configuration.lifecycle_handler = stub_name

    @service.restore_account(identity: @identity)

    assert_equal @identity, called_with
  ensure
    RSB::Auth.configuration.lifecycle_handler = nil
    RSB::Auth.send(:remove_const, :TestRestoredIdentityHandler) if RSB::Auth.const_defined?(:TestRestoredIdentityHandler)
  end

  test "restore_account for non-deleted identity fails" do
    active_identity = RSB::Auth::Identity.create!(status: :active)

    result = @service.restore_account(identity: active_identity)

    assert_not result.success?
    assert_includes result.errors, "Identity is not in deleted status."
  end

  test "restore_account for suspended identity fails" do
    suspended_identity = RSB::Auth::Identity.create!(status: :suspended)

    result = @service.restore_account(identity: suspended_identity)

    assert_not result.success?
    assert_includes result.errors, "Identity is not in deleted status."
  end

  test "restore_account does NOT restore revoked credentials" do
    @service.restore_account(identity: @identity)

    assert @credential.reload.revoked?
  end
end
