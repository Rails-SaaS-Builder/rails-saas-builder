require "test_helper"

class RSB::Auth::LifecycleHandlerTest < ActiveSupport::TestCase
  setup do
    @handler = RSB::Auth::LifecycleHandler.new
  end

  test "after_identity_created is a no-op that accepts an identity" do
    assert_nil @handler.after_identity_created("fake_identity")
  end

  test "after_session_created is a no-op that accepts a session" do
    assert_nil @handler.after_session_created("fake_session")
  end

  test "after_credential_locked is a no-op that accepts a credential" do
    assert_nil @handler.after_credential_locked("fake_credential")
  end

  test "after_identity_verified is a no-op that accepts an identity" do
    assert_nil @handler.after_identity_verified("fake_identity")
  end

  test "subclass can override after_identity_created" do
    custom = Class.new(RSB::Auth::LifecycleHandler) do
      attr_reader :called_with
      def after_identity_created(identity)
        @called_with = identity
      end
    end.new

    custom.after_identity_created("my_identity")
    assert_equal "my_identity", custom.called_with
  end

  test "subclass can override after_session_created" do
    custom = Class.new(RSB::Auth::LifecycleHandler) do
      attr_reader :called_with
      def after_session_created(session)
        @called_with = session
      end
    end.new

    custom.after_session_created("my_session")
    assert_equal "my_session", custom.called_with
  end

  test "subclass can override after_credential_locked" do
    custom = Class.new(RSB::Auth::LifecycleHandler) do
      attr_reader :called_with
      def after_credential_locked(credential)
        @called_with = credential
      end
    end.new

    custom.after_credential_locked("my_credential")
    assert_equal "my_credential", custom.called_with
  end

  test "subclass can override after_identity_verified" do
    custom = Class.new(RSB::Auth::LifecycleHandler) do
      attr_reader :called_with
      def after_identity_verified(identity)
        @called_with = identity
      end
    end.new

    custom.after_identity_verified("my_identity")
    assert_equal "my_identity", custom.called_with
  end

  test "exceptions in handler methods propagate" do
    custom = Class.new(RSB::Auth::LifecycleHandler) do
      def after_identity_created(_identity)
        raise "boom"
      end
    end.new

    assert_raises(RuntimeError, "boom") do
      custom.after_identity_created("identity")
    end
  end
end
