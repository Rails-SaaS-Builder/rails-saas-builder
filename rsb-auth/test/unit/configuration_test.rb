require "test_helper"

class RSB::Auth::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = RSB::Auth::Configuration.new
  end

  test "lifecycle_handler defaults to nil" do
    assert_nil @config.lifecycle_handler
  end

  test "lifecycle_handler is assignable as a string" do
    @config.lifecycle_handler = "RSB::Auth::LifecycleHandler"
    assert_equal "RSB::Auth::LifecycleHandler", @config.lifecycle_handler
  end

  test "resolve_lifecycle_handler returns base handler when lifecycle_handler is nil" do
    handler = @config.resolve_lifecycle_handler
    assert_instance_of RSB::Auth::LifecycleHandler, handler
  end

  test "resolve_lifecycle_handler constantizes and instantiates when set" do
    @config.lifecycle_handler = "RSB::Auth::LifecycleHandler"
    handler = @config.resolve_lifecycle_handler
    assert_instance_of RSB::Auth::LifecycleHandler, handler
  end

  test "resolve_lifecycle_handler returns a new instance each time" do
    @config.lifecycle_handler = "RSB::Auth::LifecycleHandler"
    handler1 = @config.resolve_lifecycle_handler
    handler2 = @config.resolve_lifecycle_handler
    assert_not_same handler1, handler2
  end

  test "resolve_lifecycle_handler raises NameError for invalid class name" do
    @config.lifecycle_handler = "NonExistent::Handler"
    assert_raises(NameError) do
      @config.resolve_lifecycle_handler
    end
  end

  test "resolve_lifecycle_handler works with custom subclass" do
    # Define an inline subclass for testing
    custom_class = Class.new(RSB::Auth::LifecycleHandler)
    stub_name = "RSB::Auth::TestCustomHandler009"
    RSB::Auth.const_set(:TestCustomHandler009, custom_class)

    @config.lifecycle_handler = stub_name
    handler = @config.resolve_lifecycle_handler
    assert_instance_of custom_class, handler
  ensure
    RSB::Auth.send(:remove_const, :TestCustomHandler009) if RSB::Auth.const_defined?(:TestCustomHandler009)
  end

  # --- Concern arrays ---

  test "identity_concerns defaults to empty array" do
    assert_equal [], @config.identity_concerns
  end

  test "credential_concerns defaults to empty array" do
    assert_equal [], @config.credential_concerns
  end

  test "identity_concerns is appendable via <<" do
    mod = Module.new
    @config.identity_concerns << mod
    assert_includes @config.identity_concerns, mod
  end

  test "credential_concerns is appendable via <<" do
    mod = Module.new
    @config.credential_concerns << mod
    assert_includes @config.credential_concerns, mod
  end

  test "multiple concerns accumulate in order" do
    mod_a = Module.new
    mod_b = Module.new
    @config.identity_concerns << mod_a
    @config.identity_concerns << mod_b
    assert_equal [mod_a, mod_b], @config.identity_concerns
  end

  test "reset! clears concern arrays" do
    RSB::Auth.configuration.identity_concerns << Module.new
    RSB::Auth.configuration.credential_concerns << Module.new
    RSB::Auth.reset!
    assert_equal [], RSB::Auth.configuration.identity_concerns
    assert_equal [], RSB::Auth.configuration.credential_concerns
  end

  test "does not respond to removed lambda accessors" do
    assert_not_respond_to @config, :after_identity_created
    assert_not_respond_to @config, :after_session_created
    assert_not_respond_to @config, :after_credential_locked
    assert_not_respond_to @config, :after_identity_verified
  end
end
