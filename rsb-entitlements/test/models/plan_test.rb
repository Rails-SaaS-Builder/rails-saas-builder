require "test_helper"

class RSB::Entitlements::PlanTest < ActiveSupport::TestCase
  def valid_plan_attributes
    {
      name: "Pro",
      slug: "pro-#{SecureRandom.hex(4)}",
      interval: "monthly",
      price_cents: 2900,
      currency: "usd",
      features: { "api_access" => true, "custom_branding" => true },
      limits: {
        "projects" => { "limit" => 50, "period" => nil },
        "storage_gb" => { "limit" => 100, "period" => nil }
      },
      metadata: {},
      active: true
    }
  end

  test "creates a valid plan" do
    plan = RSB::Entitlements::Plan.create!(valid_plan_attributes)
    assert plan.persisted?
  end

  test "validates presence of name" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(name: nil))
    refute plan.valid?
    assert_includes plan.errors[:name], "can't be blank"
  end

  test "validates presence of slug" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(slug: nil))
    refute plan.valid?
    assert_includes plan.errors[:slug], "can't be blank"
  end

  test "validates slug format — only lowercase, digits, hyphens, underscores" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(slug: "Invalid Slug!"))
    refute plan.valid?
    assert_includes plan.errors[:slug], "is invalid"
  end

  test "validates slug format allows valid slugs" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(slug: "pro-plan_2"))
    assert plan.valid?
  end

  test "validates slug uniqueness" do
    RSB::Entitlements::Plan.create!(valid_plan_attributes.merge(slug: "unique-slug"))
    duplicate = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(slug: "unique-slug"))
    refute duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "validates presence of interval" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(interval: nil))
    refute plan.valid?
    assert_includes plan.errors[:interval], "can't be blank"
  end

  test "validates interval inclusion" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(interval: "biweekly"))
    refute plan.valid?
    assert_includes plan.errors[:interval], "is not included in the list"
  end

  test "validates all valid intervals" do
    %w[monthly yearly lifetime one_time].each do |interval|
      plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(interval: interval, slug: "slug-#{interval}"))
      assert plan.valid?, "Expected interval '#{interval}' to be valid"
    end
  end

  test "validates presence of price_cents" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(price_cents: nil))
    refute plan.valid?
    assert_includes plan.errors[:price_cents], "can't be blank"
  end

  test "validates price_cents is not negative" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(price_cents: -1))
    refute plan.valid?
    assert_includes plan.errors[:price_cents], "must be greater than or equal to 0"
  end

  test "validates presence of currency" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(currency: nil))
    refute plan.valid?
    assert_includes plan.errors[:currency], "can't be blank"
  end

  test "free? returns true when price_cents is 0" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(price_cents: 0))
    assert plan.free?
  end

  test "free? returns false when price_cents is positive" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(price_cents: 100))
    refute plan.free?
  end

  test "feature? returns true when feature is enabled" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(features: { "api_access" => true }))
    assert plan.feature?("api_access")
    assert plan.feature?(:api_access)
  end

  test "feature? returns false when feature is not present" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(features: {}))
    refute plan.feature?("api_access")
  end

  test "feature? returns false when feature is false" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(features: { "api_access" => false }))
    refute plan.feature?("api_access")
  end

  test "limit_for returns limit value" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(
      limits: { "projects" => { "limit" => 50, "period" => nil } }
    ))
    assert_equal 50, plan.limit_for("projects")
    assert_equal 50, plan.limit_for(:projects)
  end

  test "limit_for returns nil for unknown metric" do
    plan = RSB::Entitlements::Plan.new(valid_plan_attributes.merge(limits: {}))
    assert_nil plan.limit_for("nonexistent")
  end

  test "active scope returns only active plans" do
    active = RSB::Entitlements::Plan.create!(valid_plan_attributes.merge(slug: "active-plan", active: true))
    inactive = RSB::Entitlements::Plan.create!(valid_plan_attributes.merge(slug: "inactive-plan", active: false))

    result = RSB::Entitlements::Plan.active
    assert_includes result, active
    assert_not_includes result, inactive
  end

  test "has_many entitlements" do
    plan = RSB::Entitlements::Plan.create!(valid_plan_attributes)
    assert_respond_to plan, :entitlements
  end
end
