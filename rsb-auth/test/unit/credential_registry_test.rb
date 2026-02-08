require "test_helper"

class RSB::Auth::CredentialRegistryTest < ActiveSupport::TestCase
  setup do
    @registry = RSB::Auth::CredentialRegistry.new
  end

  test "register stores a definition by key" do
    defn = RSB::Auth::CredentialDefinition.new(key: :email_password, class_name: "TestClass")
    @registry.register(defn)

    assert_equal 1, @registry.all.size
    assert_equal defn, @registry.find(:email_password)
  end

  test "register raises ArgumentError for non-CredentialDefinition" do
    assert_raises(ArgumentError) { @registry.register("not a definition") }
    assert_raises(ArgumentError) { @registry.register(42) }
  end

  test "find returns definition by key" do
    defn = RSB::Auth::CredentialDefinition.new(key: :oauth, class_name: "OAuthClass")
    @registry.register(defn)

    found = @registry.find(:oauth)
    assert_equal :oauth, found.key
  end

  test "find returns nil for unknown key" do
    assert_nil @registry.find(:nonexistent)
  end

  test "all returns all registered definitions" do
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :a, class_name: "A"))
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :b, class_name: "B"))

    assert_equal 2, @registry.all.size
  end

  test "authenticatable returns only authenticatable definitions" do
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :a, class_name: "A", authenticatable: true))
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :b, class_name: "B", authenticatable: false))

    result = @registry.authenticatable
    assert_equal 1, result.size
    assert_equal :a, result.first.key
  end

  test "registerable returns only registerable definitions" do
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :a, class_name: "A", registerable: true))
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :b, class_name: "B", registerable: false))

    result = @registry.registerable
    assert_equal 1, result.size
    assert_equal :a, result.first.key
  end

  test "for_identifier returns definition matching identifier_password pattern" do
    defn = RSB::Auth::CredentialDefinition.new(key: :email_password, class_name: "EmailPasswordClass")
    @registry.register(defn)

    found = @registry.for_identifier("email")
    assert_equal :email_password, found.key
    assert_equal "EmailPasswordClass", found.class_name
  end

  test "for_identifier returns nil for unregistered identifier" do
    assert_nil @registry.for_identifier("unknown")
  end

  test "keys returns all registered keys" do
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :a, class_name: "A"))
    @registry.register(RSB::Auth::CredentialDefinition.new(key: :b, class_name: "B"))

    assert_equal [:a, :b], @registry.keys
  end
end
