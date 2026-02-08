require "test_helper"

class RegistryTest < ActiveSupport::TestCase
  setup do
    @registry = RSB::Admin::Registry.new
  end

  test "register_category creates a category" do
    @registry.register_category "Authentication"

    assert @registry.category?("Authentication")
    assert_kind_of RSB::Admin::CategoryRegistration, @registry.categories["Authentication"]
  end

  test "register_category evaluates the block" do
    @registry.register_category "System" do
      resource RSB::Admin::Role, icon: "shield", actions: [:index, :show]
    end

    assert @registry.category?("System")
    assert_equal 1, @registry.categories["System"].resources.size
  end

  test "register_category merges into existing category" do
    @registry.register_category "System" do
      resource RSB::Admin::Role, actions: [:index]
    end

    @registry.register_category "System" do
      resource RSB::Admin::AdminUser, actions: [:show]
    end

    assert_equal 2, @registry.categories["System"].resources.size
  end

  test "register_in is an alias for register_category" do
    @registry.register_in "Auth" do
      resource RSB::Admin::Role, actions: [:index]
    end

    assert @registry.category?("Auth")
    assert_equal 1, @registry.categories["Auth"].resources.size
  end

  test "register accepts a pre-built CategoryRegistration" do
    cat = RSB::Admin::CategoryRegistration.new("Billing")
    cat.resource RSB::Admin::Role, actions: [:index]

    @registry.register(cat)

    assert @registry.category?("Billing")
    assert_equal 1, @registry.categories["Billing"].resources.size
  end

  test "register merges into existing category when name matches" do
    @registry.register_category "Auth" do
      resource RSB::Admin::Role, actions: [:index]
    end

    cat = RSB::Admin::CategoryRegistration.new("Auth")
    cat.resource RSB::Admin::AdminUser, actions: [:show]

    @registry.register(cat)

    assert_equal 2, @registry.categories["Auth"].resources.size
  end

  test "find_resource searches across all categories" do
    @registry.register_category "System" do
      resource RSB::Admin::Role, actions: [:index]
    end

    @registry.register_category "Admin" do
      resource RSB::Admin::AdminUser, actions: [:show]
    end

    found = @registry.find_resource(RSB::Admin::AdminUser)
    assert_not_nil found
    assert_equal RSB::Admin::AdminUser, found.model_class
  end

  test "find_resource returns nil when not found" do
    result = @registry.find_resource(String)
    assert_nil result
  end

  test "category? returns true for existing categories" do
    @registry.register_category "Auth"
    assert @registry.category?("Auth")
    refute @registry.category?("NonExistent")
  end

  test "all_resources aggregates across categories" do
    @registry.register_category "A" do
      resource RSB::Admin::Role, actions: [:index]
    end
    @registry.register_category "B" do
      resource RSB::Admin::AdminUser, actions: [:show]
    end

    assert_equal 2, @registry.all_resources.size
  end

  test "all_pages aggregates across categories" do
    @registry.register_category "A" do
      page :page1, label: "Page 1", icon: "x", controller: "ctrl1"
    end
    @registry.register_category "B" do
      page :page2, label: "Page 2", icon: "y", controller: "ctrl2"
    end

    assert_equal 2, @registry.all_pages.size
  end
end
