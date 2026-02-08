require "test_helper"

class RSB::Auth::SessionTest < ActiveSupport::TestCase
  setup do
    register_test_schema("auth", password_min_length: 8, session_duration: 86_400)
    @identity = RSB::Auth::Identity.create!
    @identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "session-test@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
  end

  test "creation generates a unique non-blank token" do
    session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )
    assert session.token.present?
    assert session.token.length >= 32
  end

  test "creation sets expires_at based on configured session_duration" do
    freeze_time do
      session = @identity.sessions.create!(
        ip_address: "127.0.0.1",
        user_agent: "TestBrowser/1.0",
        last_active_at: Time.current
      )
      expected = Time.current + 86_400.seconds
      assert_equal expected, session.expires_at
    end
  end

  test "expired? returns true when expires_at is in the past" do
    session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )
    session.update_columns(expires_at: 1.hour.ago)
    assert session.expired?
  end

  test "expired? returns false when expires_at is in the future" do
    session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )
    assert_not session.expired?
  end

  test "revoke! sets expires_at to current time" do
    freeze_time do
      session = @identity.sessions.create!(
        ip_address: "127.0.0.1",
        user_agent: "TestBrowser/1.0",
        last_active_at: Time.current
      )
      session.revoke!
      assert_equal Time.current, session.expires_at
      assert session.expired?
    end
  end

  test "touch_activity! updates last_active_at without updating updated_at" do
    freeze_time do
      session = @identity.sessions.create!(
        ip_address: "127.0.0.1",
        user_agent: "TestBrowser/1.0",
        last_active_at: 1.hour.ago
      )
      original_updated_at = session.updated_at

      travel 30.minutes
      session.touch_activity!

      assert_equal Time.current, session.last_active_at
      assert_equal original_updated_at, session.updated_at
    end
  end

  test "active scope returns only non-expired sessions" do
    active_session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )

    expired_session = @identity.sessions.create!(
      ip_address: "127.0.0.2",
      user_agent: "TestBrowser/2.0",
      last_active_at: Time.current
    )
    expired_session.update_columns(expires_at: 1.hour.ago)

    active_sessions = RSB::Auth::Session.active
    assert_includes active_sessions, active_session
    assert_not_includes active_sessions, expired_session
  end

  test "expired scope returns only expired sessions" do
    active_session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )

    expired_session = @identity.sessions.create!(
      ip_address: "127.0.0.2",
      user_agent: "TestBrowser/2.0",
      last_active_at: Time.current
    )
    expired_session.update_columns(expires_at: 1.hour.ago)

    expired_sessions = RSB::Auth::Session.expired
    assert_includes expired_sessions, expired_session
    assert_not_includes expired_sessions, active_session
  end

  test "after_session_created lifecycle handler fires on create" do
    called_with = nil
    custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_session_created) { |session| called_with = session }
    end
    stub_name = "RSB::Auth::TestSessionCreatedHandler"
    RSB::Auth.const_set(:TestSessionCreatedHandler, custom_handler)
    RSB::Auth.configuration.lifecycle_handler = stub_name

    session = @identity.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "TestBrowser/1.0",
      last_active_at: Time.current
    )

    assert_equal session, called_with
  ensure
    RSB::Auth.configuration.lifecycle_handler = nil
    RSB::Auth.send(:remove_const, :TestSessionCreatedHandler) if RSB::Auth.const_defined?(:TestSessionCreatedHandler)
  end

  test "lifecycle handler no-op when no handler configured" do
    RSB::Auth.configuration.lifecycle_handler = nil

    assert_nothing_raised do
      @identity.sessions.create!(
        ip_address: "127.0.0.1",
        user_agent: "TestBrowser/1.0",
        last_active_at: Time.current
      )
    end
  end
end
