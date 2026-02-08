require "test_helper"

class RSB::Auth::LifecycleHandlerRevocationTest < ActiveSupport::TestCase
  test "after_credential_revoked is a no-op by default" do
    handler = RSB::Auth::LifecycleHandler.new
    assert_nothing_raised { handler.after_credential_revoked(nil) }
  end

  test "after_credential_restored is a no-op by default" do
    handler = RSB::Auth::LifecycleHandler.new
    assert_nothing_raised { handler.after_credential_restored(nil) }
  end

  test "subclass can override after_credential_revoked" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_credential_revoked) { |cred| called_with = cred }
    end

    handler_class.new.after_credential_revoked(:fake_credential)
    assert_equal :fake_credential, called_with
  end

  test "subclass can override after_credential_restored" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_credential_restored) { |cred| called_with = cred }
    end

    handler_class.new.after_credential_restored(:fake_credential)
    assert_equal :fake_credential, called_with
  end
end
