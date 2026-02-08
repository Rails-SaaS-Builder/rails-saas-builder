require "test_helper"
require "rsb/admin/test_kit"

class TestKitHelpersTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  test "create_test_admin! creates an admin with superadmin role" do
    admin = create_test_admin!(superadmin: true)

    assert admin.persisted?
    assert admin.role.present?
    assert admin.role.superadmin?
    assert admin.can?("anything", "any_action")
  end

  test "create_test_admin! with default args creates superadmin" do
    admin = create_test_admin!

    assert admin.persisted?
    assert admin.role.superadmin?
  end

  test "create_test_admin! with specific permissions" do
    admin = create_test_admin!(permissions: { "articles" => ["index", "show"] })

    assert admin.persisted?
    refute admin.role.superadmin?
    assert admin.can?("articles", "index")
    refute admin.can?("articles", "destroy")
  end

  test "create_test_admin! with custom email and password" do
    admin = create_test_admin!(email: "custom@example.com", password: "my-password-123")

    assert_equal "custom@example.com", admin.email
    assert admin.authenticate("my-password-123")
  end

  test "sign_in_admin signs in the admin" do
    admin = create_test_admin!
    sign_in_admin(admin)
    assert_redirected_to rsb_admin.dashboard_path
  end

  test "assert_admin_authorized passes on success response" do
    admin = create_test_admin!
    sign_in_admin(admin)
    get rsb_admin.dashboard_path
    assert_admin_authorized
  end

  test "assert_admin_denied passes on forbidden response" do
    admin = create_test_admin!(permissions: { "dashboard" => ["index"] })
    sign_in_admin(admin)
    get rsb_admin.roles_path
    assert_admin_denied
  end

  test "with_fresh_admin_registry provides isolated registry" do
    RSB::Admin.registry.register_category "Existing"

    with_fresh_admin_registry do |registry|
      refute registry.category?("Existing")
      registry.register_category "Fresh"
      assert registry.category?("Fresh")
    end

    # Original registry is restored
    assert RSB::Admin.registry.category?("Existing")
    refute RSB::Admin.registry.category?("Fresh")
  end

  test "assert_admin_resource_registered checks resource and category" do
    RSB::Admin.registry.register_category "System" do
      resource RSB::Admin::Role, actions: [:index]
    end

    assert_admin_resource_registered RSB::Admin::Role, category: "System"
  end
end
