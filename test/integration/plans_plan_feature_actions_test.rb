# frozen_string_literal: true

require 'test_helper'

# Integration tests for PlanFeature CUD via plan-scoped custom actions on
# PlansController. PlanFeature has NO standalone admin URLs — every action
# is nested under /admin/plans/:id/... and always redirects back there.
class PlansPlanFeatureActionsTest < ActionDispatch::IntegrationTest
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @plan    = create_test_plan(key: 'pro', name: 'Pro')
    @flag    = create_test_feature(key: 'sso',       kind: 'flag',    unit: nil)
    @metered = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    @gauge   = create_test_feature(key: 'storage',   kind: 'gauge',   unit: 'bytes')
  end

  # ---------- Standalone PlanFeature URLs no longer exist ----------

  test 'POST /admin/plan_features routes nowhere (404)' do
    post '/admin/plan_features', params: {
      plan_feature: { plan_key: @plan.key, feature_key: 'sso', enabled: 'true' }
    }
    assert_response :not_found
  end

  test 'DELETE /admin/plan_features/:id routes nowhere (404)' do
    pf = attach_test_feature(plan: @plan, feature: @flag, enabled: true)
    delete "/admin/plan_features/#{pf.id}"
    assert_response :not_found
  end

  # ---------- Create via attach_feature POST ----------

  test 'POST /admin/plans/:id/attach_feature creates a flag PlanFeature and redirects to Plan show' do
    assert_difference -> { RSB::Entitlements::PlanFeature.count }, 1 do
      post "/admin/plans/#{@plan.id}/attach_feature", params: {
        plan_feature: { feature_key: 'sso', enabled: 'true' }
      }
    end
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf = RSB::Entitlements::PlanFeature.find_by!(plan_key: @plan.key, feature_key: 'sso')
    assert_equal true, pf.enabled
    assert_nil pf.period
    assert_nil pf.limit_value
  end

  test 'POST /admin/plans/:id/attach_feature creates a metered PlanFeature and redirects to Plan show' do
    assert_difference -> { RSB::Entitlements::PlanFeature.count }, 1 do
      post "/admin/plans/#{@plan.id}/attach_feature", params: {
        plan_feature: { feature_key: 'api_calls', limit_value: '500', period: 'month' }
      }
    end
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf = RSB::Entitlements::PlanFeature.find_by!(plan_key: @plan.key, feature_key: 'api_calls')
    assert_equal 500, pf.limit_value
    assert_equal 'month', pf.period
  end

  test 'POST /admin/plans/:id/attach_feature creates a gauge PlanFeature and redirects to Plan show' do
    assert_difference -> { RSB::Entitlements::PlanFeature.count }, 1 do
      post "/admin/plans/#{@plan.id}/attach_feature", params: {
        plan_feature: { feature_key: 'storage', limit_value: '1000000' }
      }
    end
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf = RSB::Entitlements::PlanFeature.find_by!(plan_key: @plan.key, feature_key: 'storage')
    assert_equal 1_000_000, pf.limit_value
    assert_nil pf.period
  end

  test 'POST /admin/plans/:id/attach_feature redirects to step 2 with errors on validation failure' do
    # metered feature with no period violates grant_shape
    post "/admin/plans/#{@plan.id}/attach_feature", params: {
      plan_feature: { feature_key: 'api_calls', limit_value: '500' }
    }
    assert_response :redirect
    assert_match(%r{/admin/plans/#{@plan.id}/attach_feature\?feature_key=api_calls}, @response.location)
  end

  test 'POST /admin/plans/:id/attach_feature with already-attached feature redirects to picker with alert' do
    attach_test_feature(plan: @plan, feature: @flag, enabled: true)
    post "/admin/plans/#{@plan.id}/attach_feature", params: {
      plan_feature: { feature_key: 'sso', enabled: 'true' }
    }
    assert_response :redirect
    assert_match(%r{/admin/plans/#{@plan.id}/attach_feature\z}, @response.location)
    follow_redirect!
    assert_match 'no longer available', response.body
  end

  test 'POST /admin/plans/:id/attach_feature ignores tampered plan_key in params (uses URL plan)' do
    other_plan = create_test_plan(key: 'free', name: 'Free')
    post "/admin/plans/#{@plan.id}/attach_feature", params: {
      plan_feature: { plan_key: other_plan.key, feature_key: 'sso', enabled: 'true' }
    }
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf = RSB::Entitlements::PlanFeature.find_by!(feature_key: 'sso')
    assert_equal @plan.key, pf.plan_key, 'plan_key must come from URL, not form params'
  end

  # ---------- Edit ----------

  test 'GET /admin/plans/:id/edit_plan_feature renders flag-only form' do
    pf = attach_test_feature(plan: @plan, feature: @flag, enabled: true)
    get "/admin/plans/#{@plan.id}/edit_plan_feature", params: { plan_feature_id: pf.id }
    assert_response :success
    assert_match 'name="plan_feature[enabled]"', response.body
    refute_match 'name="plan_feature[period]"', response.body
    refute_match 'name="plan_feature[limit_value]"', response.body
    refute_match 'name="plan_feature[plan_key]"', response.body
    refute_match 'name="plan_feature[feature_key]"', response.body
  end

  test 'GET /admin/plans/:id/edit_plan_feature renders metered form (limit + period)' do
    pf = attach_test_feature(plan: @plan, feature: @metered, limit_value: 500, period: 'month')
    get "/admin/plans/#{@plan.id}/edit_plan_feature", params: { plan_feature_id: pf.id }
    assert_response :success
    assert_match 'name="plan_feature[limit_value]"', response.body
    assert_match 'name="plan_feature[period]"', response.body
    refute_match 'name="plan_feature[enabled]"', response.body
    assert_match 'value="500"', response.body
  end

  test 'GET /admin/plans/:id/edit_plan_feature renders gauge form (limit only)' do
    pf = attach_test_feature(plan: @plan, feature: @gauge, limit_value: 1_000_000)
    get "/admin/plans/#{@plan.id}/edit_plan_feature", params: { plan_feature_id: pf.id }
    assert_response :success
    assert_match 'name="plan_feature[limit_value]"', response.body
    refute_match 'name="plan_feature[period]"', response.body
    refute_match 'name="plan_feature[enabled]"', response.body
    assert_match 'value="1000000"', response.body
  end

  test 'PATCH /admin/plans/:id/edit_plan_feature updates and redirects to Plan show' do
    pf = attach_test_feature(plan: @plan, feature: @metered, limit_value: 100, period: 'month')
    patch "/admin/plans/#{@plan.id}/edit_plan_feature",
          params: { plan_feature_id: pf.id, plan_feature: { limit_value: '5000', period: 'year' } }
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf.reload
    assert_equal 5000,   pf.limit_value
    assert_equal 'year', pf.period
  end

  test 'PATCH /admin/plans/:id/edit_plan_feature ignores plan_key + feature_key changes' do
    pf = attach_test_feature(plan: @plan, feature: @gauge, limit_value: 100)
    other_plan    = create_test_plan(key: 'free', name: 'Free')
    other_feature = create_test_feature(key: 'storage_v2', kind: 'gauge')
    patch "/admin/plans/#{@plan.id}/edit_plan_feature",
          params: { plan_feature_id: pf.id, plan_feature: { plan_key: other_plan.key, feature_key: other_feature.key, limit_value: '99' } }
    assert_redirected_to "/admin/plans/#{@plan.id}"
    pf.reload
    assert_equal @plan.key,  pf.plan_key
    assert_equal @gauge.key, pf.feature_key
    assert_equal 99, pf.limit_value
  end

  test 'PATCH /admin/plans/:id/edit_plan_feature with invalid params re-renders edit' do
    pf = attach_test_feature(plan: @plan, feature: @metered, limit_value: 100, period: 'month')
    patch "/admin/plans/#{@plan.id}/edit_plan_feature",
          params: { plan_feature_id: pf.id, plan_feature: { limit_value: '5000', period: '' } }
    assert_response :unprocessable_content
    pf.reload
    assert_equal 100, pf.limit_value, 'change must roll back on validation failure'
  end

  test 'PATCH /admin/plans/:id/edit_plan_feature with mismatched plan_feature_id returns 404' do
    other_plan = create_test_plan(key: 'free', name: 'Free')
    pf_on_other = attach_test_feature(plan: other_plan, feature: @flag, enabled: true)
    patch "/admin/plans/#{@plan.id}/edit_plan_feature",
          params: { plan_feature_id: pf_on_other.id, plan_feature: { enabled: 'false' } }
    assert_response :not_found
  end

  # ---------- Destroy ----------

  test 'POST /admin/plans/:id/destroy_plan_feature destroys and redirects to Plan show' do
    pf = attach_test_feature(plan: @plan, feature: @flag, enabled: true)
    assert_difference -> { RSB::Entitlements::PlanFeature.count }, -1 do
      post "/admin/plans/#{@plan.id}/destroy_plan_feature", params: { plan_feature_id: pf.id }
    end
    assert_redirected_to "/admin/plans/#{@plan.id}"
  end

  test 'POST /admin/plans/:id/destroy_plan_feature with mismatched plan_feature_id returns 404' do
    other_plan = create_test_plan(key: 'free', name: 'Free')
    pf_on_other = attach_test_feature(plan: other_plan, feature: @flag, enabled: true)
    post "/admin/plans/#{@plan.id}/destroy_plan_feature", params: { plan_feature_id: pf_on_other.id }
    assert_response :not_found
  end
end
