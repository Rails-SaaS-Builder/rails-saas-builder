require "test_helper"

class RSB::Auth::SessionServiceTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth",
      password_min_length: 8,
      session_duration: 86_400,
      max_sessions: 5
    )
    @identity = RSB::Auth::Identity.create!
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "session-svc@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    @service = RSB::Auth::SessionService.new
  end

  test "create creates a session for the identity" do
    session = @service.create(
      identity: @identity,
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser"
    )

    assert_instance_of RSB::Auth::Session, session
    assert_equal @identity, session.identity
    assert session.token.present?
  end

  test "find_by_token returns session for valid token" do
    session = @service.create(
      identity: @identity,
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser"
    )

    found = @service.find_by_token(session.token)
    assert_equal session, found
  end

  test "find_by_token returns nil for blank token" do
    assert_nil @service.find_by_token(nil)
    assert_nil @service.find_by_token("")
  end

  test "find_by_token returns nil for expired session" do
    session = @service.create(
      identity: @identity,
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser"
    )
    session.update_columns(expires_at: 1.hour.ago)

    assert_nil @service.find_by_token(session.token)
  end

  test "revoke marks session as expired" do
    session = @service.create(
      identity: @identity,
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser"
    )

    @service.revoke(session)
    assert session.expired?
  end

  test "revoke_all revokes all sessions except specified" do
    s1 = @service.create(identity: @identity, ip_address: "1.1.1.1", user_agent: "A")
    s2 = @service.create(identity: @identity, ip_address: "2.2.2.2", user_agent: "B")
    s3 = @service.create(identity: @identity, ip_address: "3.3.3.3", user_agent: "C")

    @service.revoke_all(@identity, except: s1)

    assert_not s1.reload.expired?
    assert s2.reload.expired?
    assert s3.reload.expired?
  end

  test "enforces session limit by revoking oldest" do
    with_settings("auth.max_sessions" => 2) do
      s1 = @service.create(identity: @identity, ip_address: "1.1.1.1", user_agent: "A")
      s2 = @service.create(identity: @identity, ip_address: "2.2.2.2", user_agent: "B")
      s3 = @service.create(identity: @identity, ip_address: "3.3.3.3", user_agent: "C")

      assert s1.reload.expired?
      assert_not s2.reload.expired?
      assert_not s3.reload.expired?
    end
  end
end
