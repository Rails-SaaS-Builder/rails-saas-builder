require_relative "../../test_helper"

class EntitlementsAdminRegistrationTest < ActiveSupport::TestCase
  setup do
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)
  end

  test "Plan resource has explicit columns" do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Plan)
    assert reg, "Plan not registered"
    assert reg.columns, "Plan should have explicit columns"

    # Verify we have 11 columns
    assert_equal 11, reg.columns.size, "Plan should have 11 columns"

    column_keys = reg.columns.map(&:key)
    assert_includes column_keys, :id
    assert_includes column_keys, :name
    assert_includes column_keys, :slug
    assert_includes column_keys, :interval
    assert_includes column_keys, :price_cents
    assert_includes column_keys, :currency
    assert_includes column_keys, :active
    assert_includes column_keys, :features
    assert_includes column_keys, :limits
    assert_includes column_keys, :metadata
    assert_includes column_keys, :created_at

    # Verify formatters
    id_col = reg.columns.find { |c| c.key == :id }
    assert id_col.link, "ID column should have link: true"

    interval_col = reg.columns.find { |c| c.key == :interval }
    assert_equal :badge, interval_col.formatter, "interval should use badge formatter"

    active_col = reg.columns.find { |c| c.key == :active }
    assert_equal :badge, active_col.formatter, "active should use badge formatter"

    features_col = reg.columns.find { |c| c.key == :features }
    assert_equal :json, features_col.formatter, "features should use json formatter"

    limits_col = reg.columns.find { |c| c.key == :limits }
    assert_equal :json, limits_col.formatter, "limits should use json formatter"

    metadata_col = reg.columns.find { |c| c.key == :metadata }
    assert_equal :json, metadata_col.formatter, "metadata should use json formatter"

    created_at_col = reg.columns.find { |c| c.key == :created_at }
    assert_equal :datetime, created_at_col.formatter, "created_at should use datetime formatter"

    # Verify visibility - these should be visible only on :show
    slug_col = reg.columns.find { |c| c.key == :slug }
    currency_col = reg.columns.find { |c| c.key == :currency }
    assert_equal [:show], slug_col.visible_on, "slug should be visible only on :show"
    assert_equal [:show], currency_col.visible_on, "currency should be visible only on :show"
    assert_equal [:show], features_col.visible_on, "features should be visible only on :show"
    assert_equal [:show], limits_col.visible_on, "limits should be visible only on :show"
    assert_equal [:show], metadata_col.visible_on, "metadata should be visible only on :show"
    assert_equal [:show], created_at_col.visible_on, "created_at should be visible only on :show"
  end

  test "Plan resource has filters" do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Plan)
    assert reg.filters, "Plan should have filters"
    assert_equal 2, reg.filters.size, "Plan should have 2 filters"

    filter_keys = reg.filters.map(&:key)
    assert_includes filter_keys, :active
    assert_includes filter_keys, :interval

    # Verify filter types
    active_filter = reg.filters.find { |f| f.key == :active }
    assert_equal :boolean, active_filter.type, "active filter should be boolean type"

    interval_filter = reg.filters.find { |f| f.key == :interval }
    assert_equal :select, interval_filter.type, "interval filter should be select type"
    assert_equal %w[monthly yearly one_time], interval_filter.options, "interval filter should have correct options"
  end

  test "Plan resource has form fields" do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Plan)
    assert reg.form_fields, "Plan should have form fields"
    assert_equal 9, reg.form_fields.size, "Plan should have 9 form fields"

    field_keys = reg.form_fields.map(&:key)
    assert_includes field_keys, :name
    assert_includes field_keys, :slug
    assert_includes field_keys, :interval
    assert_includes field_keys, :price_cents
    assert_includes field_keys, :currency
    assert_includes field_keys, :active
    assert_includes field_keys, :features
    assert_includes field_keys, :limits
    assert_includes field_keys, :metadata

    # Verify some specific field properties
    name_field = reg.form_fields.find { |f| f.key == :name }
    assert name_field.required, "name field should be required"
    assert_equal :text, name_field.type

    slug_field = reg.form_fields.find { |f| f.key == :slug }
    assert slug_field.required, "slug field should be required"
    assert_equal "URL-friendly identifier", slug_field.hint

    price_cents_field = reg.form_fields.find { |f| f.key == :price_cents }
    assert price_cents_field.required, "price_cents field should be required"
    assert_equal :number, price_cents_field.type
    assert_equal "Price (cents)", price_cents_field.label
  end

  test "Plan resource has default_sort" do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Plan)
    assert reg.default_sort, "Plan should have default_sort"
    assert_equal :name, reg.default_sort[:column]
    assert_equal :asc, reg.default_sort[:direction]
  end

  test "Entitlement resource has columns and filters" do
    reg = RSB::Admin.registry.find_resource(RSB::Entitlements::Entitlement)
    assert reg, "Entitlement not registered"
    assert reg.columns, "Entitlement should have explicit columns"
    assert_equal 8, reg.columns.size, "Entitlement should have 8 columns"

    column_keys = reg.columns.map(&:key)
    assert_includes column_keys, :id
    assert_includes column_keys, :plan_id
    assert_includes column_keys, :entitleable_type
    assert_includes column_keys, :entitleable_id
    assert_includes column_keys, :status
    assert_includes column_keys, :starts_at
    assert_includes column_keys, :ends_at
    assert_includes column_keys, :created_at

    # Verify filters
    assert reg.filters, "Entitlement should have filters"
    assert_equal 2, reg.filters.size, "Entitlement should have 2 filters"

    filter_keys = reg.filters.map(&:key)
    assert_includes filter_keys, :status
    assert_includes filter_keys, :entitleable_type

    status_filter = reg.filters.find { |f| f.key == :status }
    assert_equal :select, status_filter.type
    assert_equal %w[active expired cancelled], status_filter.options

    entitleable_type_filter = reg.filters.find { |f| f.key == :entitleable_type }
    assert_equal :text, entitleable_type_filter.type
  end

  test "Usage counters page has 2 actions" do
    page = RSB::Admin.registry.find_page_by_key(:usage_counters)
    assert page, "usage_counters page not registered"
    assert_kind_of RSB::Admin::PageRegistration, page
    assert_equal 2, page.actions.size, "usage_counters page should have 2 actions"

    action_keys = page.action_keys
    assert_includes action_keys, :index
    assert_includes action_keys, :trend
  end

  test "i18n labels are available" do
    # First check if the locale file is loaded
    assert_equal "Price", I18n.t("rsb.admin.resources.plans.columns.price_cents", default: nil),
      "price_cents i18n label should be 'Price'"
  end
end
