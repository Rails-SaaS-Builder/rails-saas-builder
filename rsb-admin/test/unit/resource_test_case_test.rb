require "test_helper"
require "rsb/admin/test_kit"

class RoleResourceContractTest < RSB::Admin::TestKit::ResourceTestCase
  self.resource_class = RSB::Admin::Role
  self.category = "System"
  self.record_factory = -> {
    RSB::Admin::Role.create!(
      name: "Test Role #{SecureRandom.hex(4)}",
      permissions: { "articles" => ["index", "show"] }
    )
  }

  # Register the resource before each test (since registry gets reset)
  registers_in_admin do
    RSB::Admin.registry.register_category "System" do
      resource RSB::Admin::Role, icon: "shield", label: "Roles", actions: [:index, :show]
    end
  end

  # The contract tests (resource is registered, index renders, show renders,
  # admin with no permissions is denied) are inherited automatically.
  # We only need custom tests here.

  test "show page displays role name" do
    role = record_factory.call
    sign_in_admin(@superadmin)
    get admin_resource_path(role)
    assert_response :success
    assert_match role.name, response.body
  end
end
