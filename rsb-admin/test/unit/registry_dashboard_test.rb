require "test_helper"

class RegistryDashboardTest < ActiveSupport::TestCase
  setup do
    @registry = RSB::Admin::Registry.new
  end

  test "dashboard_page is nil by default" do
    assert_nil @registry.dashboard_page
  end

  test "register_dashboard stores a PageRegistration" do
    result = @registry.register_dashboard(controller: "admin/custom_dashboard")

    assert_kind_of RSB::Admin::PageRegistration, result
    assert_equal :dashboard, result.key
    assert_equal "Dashboard", result.label
    assert_equal "home", result.icon
    assert_equal "admin/custom_dashboard", result.controller
    assert_equal "System", result.category_name
    assert_same result, @registry.dashboard_page
  end

  test "register_dashboard with actions normalizes them" do
    @registry.register_dashboard(
      controller: "admin/dash",
      actions: [
        { key: :index, label: "Overview" },
        { key: :metrics, label: "Metrics" }
      ]
    )

    page = @registry.dashboard_page
    assert_equal 2, page.actions.length
    assert_equal :index, page.actions[0][:key]
    assert_equal "Overview", page.actions[0][:label]
    assert_equal :metrics, page.actions[1][:key]
    assert_equal "Metrics", page.actions[1][:label]
  end

  test "register_dashboard replaces previous registration (last-write-wins)" do
    @registry.register_dashboard(controller: "admin/first")
    @registry.register_dashboard(controller: "admin/second")

    assert_equal "admin/second", @registry.dashboard_page.controller
  end

  test "register_dashboard raises ArgumentError if controller is blank" do
    assert_raises(ArgumentError) { @registry.register_dashboard(controller: "") }
    assert_raises(ArgumentError) { @registry.register_dashboard(controller: nil) }
  end

  test "dashboard_page is nil after RSB::Admin.reset!" do
    RSB::Admin.registry.register_dashboard(controller: "admin/foo")
    RSB::Admin.reset!
    assert_nil RSB::Admin.registry.dashboard_page
  end
end
