require "test_helper"

class RSB::Settings::SchemaTest < ActiveSupport::TestCase
  test "defines settings with all attributes" do
    schema = RSB::Settings::Schema.new("test_category") do
      setting :my_string, type: :string, default: "hello", description: "A string setting"
      setting :my_int, type: :integer, default: 42
      setting :my_bool, type: :boolean, default: true
      setting :my_enum, type: :string, default: "a", enum: %w[a b c]
    end

    assert schema.valid?
    assert_equal "test_category", schema.category
    assert_equal [:my_string, :my_int, :my_bool, :my_enum], schema.keys
    assert_equal({ my_string: "hello", my_int: 42, my_bool: true, my_enum: "a" }, schema.defaults)
  end

  test "find returns a specific definition" do
    schema = RSB::Settings::Schema.new("cat") do
      setting :foo, type: :string, default: "bar"
      setting :baz, type: :integer, default: 1
    end

    defn = schema.find(:foo)
    assert_equal :foo, defn.key
    assert_equal :string, defn.type
    assert_equal "bar", defn.default
  end

  test "find returns nil for unknown key" do
    schema = RSB::Settings::Schema.new("cat") do
      setting :foo, type: :string, default: "bar"
    end

    assert_nil schema.find(:nonexistent)
  end

  test "valid? returns true for well-formed schema" do
    schema = RSB::Settings::Schema.new("valid") do
      setting :x, type: :string, default: "y"
    end
    assert schema.valid?
  end

  test "valid? returns false for empty category" do
    schema = RSB::Settings::Schema.new("")
    refute schema.valid?
  end

  test "setting supports encrypted and locked flags" do
    schema = RSB::Settings::Schema.new("secure") do
      setting :api_key, type: :string, encrypted: true
      setting :mode, type: :string, default: "open", locked: true
    end

    api_key_def = schema.find(:api_key)
    assert api_key_def.encrypted
    refute api_key_def.locked

    mode_def = schema.find(:mode)
    refute mode_def.encrypted
    assert mode_def.locked
  end

  test "setting supports validates option" do
    schema = RSB::Settings::Schema.new("validated") do
      setting :min_length, type: :integer, default: 8, validates: { greater_than: 5 }
    end

    defn = schema.find(:min_length)
    assert_equal({ greater_than: 5 }, defn.validates)
  end

  test "merge combines definitions from same category" do
    a = RSB::Settings::Schema.new("auth") do
      setting :mode, type: :string, default: "open"
    end
    b = RSB::Settings::Schema.new("auth") do
      setting :timeout, type: :integer, default: 30
    end

    merged = a.merge(b)
    assert_equal [:mode, :timeout], merged.keys
    assert_equal "auth", merged.category
  end

  test "merge raises for different categories" do
    a = RSB::Settings::Schema.new("auth") { setting :x, type: :string }
    b = RSB::Settings::Schema.new("billing") { setting :y, type: :string }

    assert_raises(ArgumentError) { a.merge(b) }
  end

  test "schema without block is valid if category is present" do
    schema = RSB::Settings::Schema.new("empty_but_valid")
    assert_equal [], schema.keys
    assert schema.valid?
  end
end
