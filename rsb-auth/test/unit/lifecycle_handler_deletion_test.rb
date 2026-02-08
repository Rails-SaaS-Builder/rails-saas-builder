require "test_helper"

class RSB::Auth::LifecycleHandlerDeletionTest < ActiveSupport::TestCase
  test "after_identity_deleted is a no-op by default" do
    handler = RSB::Auth::LifecycleHandler.new
    assert_nothing_raised { handler.after_identity_deleted(nil) }
  end

  test "after_identity_restored is a no-op by default" do
    handler = RSB::Auth::LifecycleHandler.new
    assert_nothing_raised { handler.after_identity_restored(nil) }
  end

  test "subclass can override after_identity_deleted" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_identity_deleted) { |identity| called_with = identity }
    end

    handler_class.new.after_identity_deleted(:fake_identity)
    assert_equal :fake_identity, called_with
  end

  test "subclass can override after_identity_restored" do
    called_with = nil
    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_identity_restored) { |identity| called_with = identity }
    end

    handler_class.new.after_identity_restored(:fake_identity)
    assert_equal :fake_identity, called_with
  end
end
