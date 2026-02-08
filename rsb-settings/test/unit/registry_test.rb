require "test_helper"

class RSB::Settings::RegistryTest < ActiveSupport::TestCase
  test "register and retrieve a schema" do
    schema = RSB::Settings::Schema.new("auth") do
      setting :mode, type: :string, default: "open"
    end

    RSB::Settings.registry.register(schema)
    retrieved = RSB::Settings.registry.for("auth")

    assert_equal "auth", retrieved.category
    assert_equal [:mode], retrieved.keys
  end

  test "register raises ArgumentError for non-Schema objects" do
    assert_raises(ArgumentError) { RSB::Settings.registry.register("not a schema") }
    assert_raises(ArgumentError) { RSB::Settings.registry.register(42) }
  end

  test "define is a shortcut for creating and registering" do
    RSB::Settings.registry.define("billing") do
      setting :currency, type: :string, default: "usd"
    end

    assert_includes RSB::Settings.registry.categories, "billing"
    schema = RSB::Settings.registry.for("billing")
    assert_equal [:currency], schema.keys
  end

  test "registering same category merges definitions" do
    RSB::Settings.registry.define("auth") { setting :a, type: :string, default: "1" }
    RSB::Settings.registry.define("auth") { setting :b, type: :string, default: "2" }

    schema = RSB::Settings.registry.for("auth")
    assert_equal [:a, :b], schema.keys
  end

  test "categories returns list of registered category names" do
    RSB::Settings.registry.define("auth") { setting :x, type: :string }
    RSB::Settings.registry.define("billing") { setting :y, type: :string }

    categories = RSB::Settings.registry.categories
    assert_includes categories, "auth"
    assert_includes categories, "billing"
  end

  test "all returns all schemas" do
    RSB::Settings.registry.define("auth") { setting :x, type: :string }
    RSB::Settings.registry.define("billing") { setting :y, type: :string }

    all = RSB::Settings.registry.all
    assert_equal 2, all.size
    assert all.all? { |s| s.is_a?(RSB::Settings::Schema) }
  end

  test "find_definition with dotted key" do
    RSB::Settings.registry.define("auth") do
      setting :mode, type: :string, default: "open"
    end

    defn = RSB::Settings.registry.find_definition("auth.mode")
    assert_equal :mode, defn.key
    assert_equal :string, defn.type
    assert_equal "open", defn.default
  end

  test "find_definition returns nil for unknown key" do
    RSB::Settings.registry.define("auth") { setting :mode, type: :string }

    assert_nil RSB::Settings.registry.find_definition("auth.nonexistent")
    assert_nil RSB::Settings.registry.find_definition("nonexistent.key")
  end

  test "on_change registers and fires callbacks" do
    fired = []
    RSB::Settings.registry.define("test") { setting :val, type: :string, default: "a" }
    RSB::Settings.registry.on_change("test.val") { |old_val, new_val| fired << [old_val, new_val] }
    RSB::Settings.registry.fire_change("test.val", "a", "b")

    assert_equal [["a", "b"]], fired
  end

  test "multiple callbacks on same key all fire" do
    results = []
    RSB::Settings.registry.on_change("test.val") { |old_val, new_val| results << "cb1: #{old_val}->#{new_val}" }
    RSB::Settings.registry.on_change("test.val") { |old_val, new_val| results << "cb2: #{old_val}->#{new_val}" }
    RSB::Settings.registry.fire_change("test.val", "x", "y")

    assert_equal ["cb1: x->y", "cb2: x->y"], results
  end

  test "fire_change with no callbacks does not raise" do
    assert_nothing_raised do
      RSB::Settings.registry.fire_change("no_callbacks.key", "a", "b")
    end
  end

  test "reset clears everything" do
    RSB::Settings.registry.define("auth") { setting :x, type: :string }
    RSB::Settings.registry.on_change("auth.x") { |_, _| }
    RSB::Settings.reset!

    assert_empty RSB::Settings.registry.categories
  end
end
