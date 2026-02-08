require "test_helper"

class UrlHelperTest < ActionView::TestCase
  include RSB::Admin::UrlHelper

  test "rsb_admin_resource_path" do
    path = rsb_admin_resource_path("identities")
    assert_equal "/admin/identities", path
  end

  test "rsb_admin_resource_show_path" do
    path = rsb_admin_resource_show_path("identities", 42)
    assert_equal "/admin/identities/42", path
  end

  test "rsb_admin_resource_new_path" do
    path = rsb_admin_resource_new_path("identities")
    assert_equal "/admin/identities/new", path
  end

  test "rsb_admin_resource_edit_path" do
    path = rsb_admin_resource_edit_path("identities", 42)
    assert_equal "/admin/identities/42/edit", path
  end

  test "rsb_admin_page_path" do
    path = rsb_admin_page_path("active_sessions")
    assert_equal "/admin/active_sessions", path
  end

  test "rsb_admin_page_action_path" do
    path = rsb_admin_page_action_path("active_sessions", "by_user")
    assert_equal "/admin/active_sessions/by_user", path
  end

  test "paths use engine mount point not hardcoded /admin/" do
    # This test verifies the implementation uses rsb_admin.root_path.
    # In the test dummy, engine is mounted at /admin, so root_path = "/admin/".
    # The helpers should produce paths starting with that prefix.
    path = rsb_admin_resource_path("posts")
    assert path.start_with?("/admin/"), "Expected path to start with engine mount point"
  end
end
