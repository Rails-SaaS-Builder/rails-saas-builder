require "test_helper"

class RSB::Auth::AccountServiceTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth", password_min_length: 8, session_duration: 86_400)
    @identity = RSB::Auth::Identity.create!(metadata: { "name" => "Original" })
    @credential = @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "account@example.com",
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

  # --- update ---

  test "update with valid params updates identity" do
    result = @service.update(identity: @identity, params: { metadata: { "name" => "Alice" } })
    assert result.success?
    assert_equal({ "name" => "Alice" }, @identity.reload.metadata)
    assert_empty result.errors
  end

  test "update returns identity in result for re-rendering" do
    result = @service.update(identity: @identity, params: { metadata: {} })
    assert_equal @identity, result.identity
  end

  test "update with invalid params returns failure" do
    # Force a validation error by setting an invalid status
    result = @service.update(identity: @identity, params: { status: "bogus" })
    assert_not result.success?
    assert result.errors.any?
    assert_equal @identity, result.identity
  end

  # --- change_password ---

  test "change_password with correct current password succeeds" do
    result = @service.change_password(
      credential: @credential,
      current_password: "password1234",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678",
      current_session: @session
    )
    assert result.success?
    assert_empty result.errors
    assert @credential.reload.authenticate("newpassword5678")
  end

  test "change_password with wrong current password fails" do
    result = @service.change_password(
      credential: @credential,
      current_password: "wrongpassword",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678",
      current_session: @session
    )
    assert_not result.success?
    assert_includes result.errors, "Current password is incorrect."
  end

  test "change_password with mismatched confirmation fails" do
    result = @service.change_password(
      credential: @credential,
      current_password: "password1234",
      new_password: "newpassword5678",
      new_password_confirmation: "different",
      current_session: @session
    )
    assert_not result.success?
    assert result.errors.any?
  end

  test "change_password with too-short new password fails" do
    result = @service.change_password(
      credential: @credential,
      current_password: "password1234",
      new_password: "short",
      new_password_confirmation: "short",
      current_session: @session
    )
    assert_not result.success?
    assert result.errors.any? { |e| e.include?("too short") }
  end

  test "change_password revokes all other sessions except current" do
    other_session = @identity.sessions.create!(
      ip_address: "10.0.0.1",
      user_agent: "OtherBrowser/1.0",
      last_active_at: Time.current
    )

    @service.change_password(
      credential: @credential,
      current_password: "password1234",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678",
      current_session: @session
    )

    assert_not @session.reload.expired?
    assert other_session.reload.expired?
  end

  test "change_password does not revoke current session" do
    @service.change_password(
      credential: @credential,
      current_password: "password1234",
      new_password: "newpassword5678",
      new_password_confirmation: "newpassword5678",
      current_session: @session
    )

    assert_not @session.reload.expired?
  end
end
