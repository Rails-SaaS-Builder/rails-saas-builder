# frozen_string_literal: true

require 'test_helper'

class AdminResourcesRegistrationTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper

  setup do
    # `next` (not `return`) — `return` from a setup-do block raises
    # LocalJumpError because the block runs via instance_exec, not as a
    # method body. Skipping when rsb-admin isn't loaded keeps these tests
    # opt-in; each individual test also calls `skip` for clarity.
    next unless defined?(RSB::Admin)

    # Reset the registry, then re-fire the on_load(:rsb_admin) callbacks so
    # the entitlements engine's admin_hooks initializer populates the registry.
    # This is necessary because the rsb-admin engine's after_initialize hook
    # (which normally fires run_load_hooks) does not run in the per-gem test env.
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)
  end

  def category
    RSB::Admin.registry.categories['Entitlements']
  end

  def resource_for(model_class)
    RSB::Admin.registry.find_resource(model_class)
  end

  test 'Entitlements category is registered' do
    skip 'rsb-admin not loaded' unless defined?(RSB::Admin)
    assert_not_nil category, 'Entitlements category not registered'
  end

  test 'Feature resource registered with archive/unarchive custom actions' do
    skip unless defined?(RSB::Admin)
    res = resource_for(RSB::Entitlements::Feature)
    assert_not_nil res
    assert_equal 'rsb/entitlements/admin/features', res.controller
    %i[index show new create edit update archive unarchive].each do |a|
      assert_includes res.actions, a, "missing action :#{a} on Feature"
    end
    assert_includes res.columns.map(&:key), :key
    assert_includes res.columns.map(&:key), :kind
    assert_includes res.columns.map(&:key), :archived_at
    assert_includes res.filters.map(&:key), :kind
    assert_includes res.form_fields.map(&:key), :name
  end

  test 'Plan resource registered with archive/unarchive custom actions' do
    skip unless defined?(RSB::Admin)
    res = resource_for(RSB::Entitlements::Plan)
    assert_not_nil res
    assert_equal 'rsb/entitlements/admin/plans', res.controller
    %i[index show new create edit update archive unarchive
       attach_feature edit_plan_feature destroy_plan_feature].each do |a|
      assert_includes res.actions, a, "missing action :#{a} on Plan"
    end
    assert_includes res.columns.map(&:key), :key
    assert_includes res.columns.map(&:key), :name
    assert_includes res.columns.map(&:key), :display_order
    assert_includes res.columns.map(&:key), :archived_at
  end

  test 'Subscription resource supports manual create + cancel (no edit/update/destroy/force_resync)' do
    skip unless defined?(RSB::Admin)
    res = resource_for(RSB::Entitlements::Subscription)
    assert_not_nil res
    assert_equal 'rsb/entitlements/admin/subscriptions', res.controller
    %i[index show new create cancel].each do |a|
      assert_includes res.actions, a, "missing action :#{a} on Subscription"
    end
    refute_includes res.actions, :edit
    refute_includes res.actions, :update
    refute_includes res.actions, :destroy
    refute_includes res.actions, :force_resync, 'force_resync was dropped in v1'
    assert_includes res.columns.map(&:key), :status
    assert_includes res.columns.map(&:key), :provider
    assert_includes res.columns.map(&:key), :raw_state
  end

  test 'UsageCounter resource is read-only with no rebuild action' do
    skip unless defined?(RSB::Admin)
    res = resource_for(RSB::Entitlements::UsageCounter)
    assert_not_nil res
    assert_nil res.controller
    assert_equal %i[index show], res.actions.sort
    refute_includes res.actions, :rebuild
    refute_includes res.actions, :reset
  end

  test 'ProviderEvent resource is read-only' do
    skip unless defined?(RSB::Admin)
    res = resource_for(RSB::Entitlements::ProviderEvent)
    assert_not_nil res
    assert_nil res.controller
    assert_equal %i[index show], res.actions.sort
  end

  test 'PaymentRequest is NOT registered (removed in v1)' do
    skip unless defined?(RSB::Admin)
    refute defined?(RSB::Entitlements::PaymentRequest),
           'PaymentRequest model should not be defined in v1'
  end

  test 'PlanFeature is NOT registered as a top-level admin resource (managed via Plan custom actions)' do
    skip unless defined?(RSB::Admin)
    # PlanFeature has no admin URLs of its own. CUD lives on PlansController
    # via plan-scoped custom actions (attach_feature, edit_plan_feature,
    # destroy_plan_feature) so all redirects always land back on Plan show.
    assert_nil resource_for(RSB::Entitlements::PlanFeature),
               'PlanFeature must NOT be a top-level admin resource'
  end
end
