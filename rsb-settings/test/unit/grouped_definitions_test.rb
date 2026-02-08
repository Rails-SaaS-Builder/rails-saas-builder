require "test_helper"

class GroupedDefinitionsTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
  end

  test "grouped_definitions returns hash grouped by group field" do
    RSB::Settings.registry.define("auth") do
      setting :session_duration,
        type: :integer,
        default: 86400,
        group: "Session & Security",
        description: "Session TTL"

      setting :max_sessions,
        type: :integer,
        default: 5,
        group: "Session & Security",
        description: "Max sessions"

      setting :registration_mode,
        type: :string,
        default: "open",
        group: "Registration",
        description: "Reg mode"
    end

    groups = RSB::Settings.registry.grouped_definitions("auth")

    assert_instance_of Hash, groups
    assert_equal ["Session & Security", "Registration"], groups.keys
    assert_equal 2, groups["Session & Security"].length
    assert_equal 1, groups["Registration"].length
    assert_equal :session_duration, groups["Session & Security"].first.key
    assert_equal :max_sessions, groups["Session & Security"].last.key
    assert_equal :registration_mode, groups["Registration"].first.key
  end

  test "grouped_definitions places nil-group settings under General" do
    RSB::Settings.registry.define("admin") do
      setting :enabled,
        type: :boolean,
        default: true,
        description: "Enabled"

      setting :app_name,
        type: :string,
        default: "Admin",
        group: "Branding",
        description: "App name"
    end

    groups = RSB::Settings.registry.grouped_definitions("admin")

    assert_equal ["General", "Branding"], groups.keys
    assert_equal :enabled, groups["General"].first.key
    assert_equal :app_name, groups["Branding"].first.key
  end

  test "grouped_definitions returns General first then groups in order of first appearance" do
    RSB::Settings.registry.define("test") do
      setting :a, type: :string, default: "", group: "Zebra", description: ""
      setting :b, type: :string, default: "", description: ""
      setting :c, type: :string, default: "", group: "Alpha", description: ""
      setting :d, type: :string, default: "", group: "Zebra", description: ""
    end

    groups = RSB::Settings.registry.grouped_definitions("test")

    # General first (from nil group on :b), then Zebra (first seen on :a), then Alpha (first seen on :c)
    assert_equal ["General", "Zebra", "Alpha"], groups.keys
  end

  test "grouped_definitions returns empty hash for unknown category" do
    groups = RSB::Settings.registry.grouped_definitions("nonexistent")
    assert_equal({}, groups)
  end

  test "grouped_definitions preserves definition order within each group" do
    RSB::Settings.registry.define("ordered") do
      setting :z_first, type: :string, default: "", group: "G", description: ""
      setting :a_second, type: :string, default: "", group: "G", description: ""
      setting :m_third, type: :string, default: "", group: "G", description: ""
    end

    groups = RSB::Settings.registry.grouped_definitions("ordered")
    keys = groups["G"].map(&:key)

    assert_equal [:z_first, :a_second, :m_third], keys
  end

  test "grouped_definitions with all settings having nil group returns single General group" do
    RSB::Settings.registry.define("flat") do
      setting :one, type: :string, default: "", description: ""
      setting :two, type: :string, default: "", description: ""
    end

    groups = RSB::Settings.registry.grouped_definitions("flat")

    assert_equal ["General"], groups.keys
    assert_equal 2, groups["General"].length
  end
end
