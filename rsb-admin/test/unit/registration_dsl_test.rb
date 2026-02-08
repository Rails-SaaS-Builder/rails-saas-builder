require "test_helper"

class ResourceRegistrationEnhancedTest < ActiveSupport::TestCase
  test "new attributes default to nil" do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System"
    )
    assert_nil reg.columns
    assert_nil reg.filters
    assert_nil reg.form_fields
    assert_nil reg.per_page
    assert_nil reg.default_sort
    assert_nil reg.search_fields
  end

  test "stores new attributes when provided" do
    cols = [RSB::Admin::ColumnDefinition.build(:id)]
    filters = [RSB::Admin::FilterDefinition.build(:email)]
    fields = [RSB::Admin::FormFieldDefinition.build(:name)]

    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System",
      columns: cols, filters: filters, form_fields: fields,
      per_page: 50, default_sort: { column: :created_at, direction: :desc },
      search_fields: [:email, :id]
    )
    assert_equal 1, reg.columns.size
    assert_equal 1, reg.filters.size
    assert_equal 1, reg.form_fields.size
    assert_equal 50, reg.per_page
    assert_equal({ column: :created_at, direction: :desc }, reg.default_sort)
    assert_equal [:email, :id], reg.search_fields
  end

  test "index_columns returns columns with visible_on :index" do
    cols = [
      RSB::Admin::ColumnDefinition.build(:id),
      RSB::Admin::ColumnDefinition.build(:secret, visible_on: [:show])
    ]
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System", columns: cols
    )
    assert_equal [:id], reg.index_columns.map(&:key)
  end

  test "show_columns returns columns with visible_on :show" do
    cols = [
      RSB::Admin::ColumnDefinition.build(:id),
      RSB::Admin::ColumnDefinition.build(:secret, visible_on: [:show])
    ]
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System", columns: cols
    )
    assert_equal [:id, :secret], reg.show_columns.map(&:key)
  end

  test "index_columns auto-detects when no columns defined" do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System"
    )
    index_cols = reg.index_columns
    assert index_cols.any?, "Should auto-detect columns from model"
    keys = index_cols.map(&:key)
    assert_includes keys, :id
    assert_includes keys, :email
    refute_includes keys, :password_digest
  end

  test "new_form_fields auto-detects when no form_fields defined" do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System"
    )
    fields = reg.new_form_fields
    keys = fields.map(&:key)
    refute_includes keys, :id
    refute_includes keys, :created_at
    refute_includes keys, :password_digest
  end

  test "edit_form_fields returns fields with visible_on :edit" do
    fields = [
      RSB::Admin::FormFieldDefinition.build(:email),
      RSB::Admin::FormFieldDefinition.build(:token, visible_on: [:new])
    ]
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::AdminUser, category_name: "System", form_fields: fields
    )
    assert_equal [:email], reg.edit_form_fields.map(&:key)
  end
end

class ResourceDSLContextTest < ActiveSupport::TestCase
  test "column adds ColumnDefinition" do
    dsl = RSB::Admin::ResourceDSLContext.new
    dsl.column :email, label: "Email Address"
    assert_equal 1, dsl.columns.size
    assert_equal :email, dsl.columns.first.key
    assert_equal "Email Address", dsl.columns.first.label
  end

  test "filter adds FilterDefinition" do
    dsl = RSB::Admin::ResourceDSLContext.new
    dsl.filter :status, type: :select, options: %w[active suspended]
    assert_equal 1, dsl.filters.size
    assert_equal :select, dsl.filters.first.type
  end

  test "form_field adds FormFieldDefinition" do
    dsl = RSB::Admin::ResourceDSLContext.new
    dsl.form_field :email, type: :email, required: true
    assert_equal 1, dsl.form_fields.size
    assert_equal :email, dsl.form_fields.first.type
    assert_equal true, dsl.form_fields.first.required
  end
end

class CategoryRegistrationDSLTest < ActiveSupport::TestCase
  setup do
    @registry = RSB::Admin::Registry.new
  end

  test "resource with block sets columns, filters, form_fields" do
    @registry.register_category "System" do
      resource RSB::Admin::AdminUser,
        icon: "users", actions: [:index, :show],
        per_page: 50, default_sort: { column: :created_at, direction: :desc } do

        column :id, link: true
        column :email, sortable: true
        filter :email, type: :text
        form_field :email, type: :email, required: true
      end
    end

    reg = @registry.find_resource(RSB::Admin::AdminUser)
    assert_equal 2, reg.columns.size
    assert_equal 1, reg.filters.size
    assert_equal 1, reg.form_fields.size
    assert_equal 50, reg.per_page
  end

  test "resource without block has nil columns/filters/form_fields (backwards compat)" do
    @registry.register_category "System" do
      resource RSB::Admin::AdminUser, actions: [:index, :show]
    end

    reg = @registry.find_resource(RSB::Admin::AdminUser)
    assert_nil reg.columns
    assert_nil reg.filters
    assert_nil reg.form_fields
  end

  test "page returns PageRegistration object" do
    @registry.register_category "System" do
      page :dashboard, label: "Dashboard", controller: "admin/dashboard"
    end

    page = @registry.find_page_by_key(:dashboard)
    assert_kind_of RSB::Admin::PageRegistration, page
    assert_equal :dashboard, page.key
    assert_equal "System", page.category_name
  end

  test "page with actions stores normalized actions" do
    @registry.register_category "Billing" do
      page :usage, label: "Usage", controller: "admin/usage",
        actions: [
          { key: :index, label: "Overview" },
          { key: :reset_all, label: "Reset All", method: :post, confirm: "Reset?" }
        ]
    end

    page = @registry.find_page_by_key(:usage)
    assert_equal 2, page.actions.size
    assert_equal :get, page.actions[0][:method]
    assert_equal :post, page.actions[1][:method]
    assert_equal "Reset?", page.actions[1][:confirm]
  end
end
