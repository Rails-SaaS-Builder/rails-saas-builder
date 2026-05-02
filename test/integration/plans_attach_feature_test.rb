# frozen_string_literal: true

require 'test_helper'

# Integration tests for the two-step server-driven PlanFeature attach flow on
# Plan show. Step 1 is a feature picker; Step 2 is a kind-specific form.
class PlansAttachFeatureTest < ActionDispatch::IntegrationTest
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @plan      = create_test_plan(key: 'pro', name: 'Pro')
    @flag      = create_test_feature(key: 'sso',       kind: 'flag', unit: nil)
    @metered   = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    @gauge     = create_test_feature(key: 'storage',   kind: 'gauge',   unit: 'bytes')
    @attached  = create_test_feature(key: 'already',   kind: 'flag', unit: nil)
    attach_test_feature(plan: @plan, feature: @attached, enabled: true)
  end

  test 'Plan show renders an Add feature link when at least one feature is unattached' do
    get "/admin/plans/#{@plan.id}"
    assert_response :success
    assert_match(%r{href="[^"]*/admin/plans/#{@plan.id}/attach_feature"}, response.body)
    assert_match 'Add feature', response.body
  end

  test 'GET /admin/plans/:id/attach_feature step 1 renders feature picker' do
    get "/admin/plans/#{@plan.id}/attach_feature"
    assert_response :success
    assert_match 'sso',       response.body, 'flag feature should appear in picker'
    assert_match 'api_calls', response.body, 'metered feature should appear in picker'
    assert_match 'storage',   response.body, 'gauge feature should appear in picker'
    refute_match(/value="already"/, response.body, 'already-attached feature must NOT appear')
  end

  test 'GET /admin/plans/:id/attach_feature?feature_key=sso renders flag-only form' do
    get "/admin/plans/#{@plan.id}/attach_feature", params: { feature_key: 'sso' }
    assert_response :success
    assert_match 'name="plan_feature[enabled]"', response.body
    refute_match 'name="plan_feature[period]"',  response.body
    refute_match 'name="plan_feature[limit_value]"', response.body
  end

  test 'GET /admin/plans/:id/attach_feature?feature_key=api_calls renders metered form' do
    get "/admin/plans/#{@plan.id}/attach_feature", params: { feature_key: 'api_calls' }
    assert_response :success
    assert_match 'name="plan_feature[limit_value]"', response.body
    assert_match 'name="plan_feature[period]"', response.body
    refute_match 'name="plan_feature[enabled]"', response.body
  end

  test 'GET /admin/plans/:id/attach_feature?feature_key=storage renders gauge form' do
    get "/admin/plans/#{@plan.id}/attach_feature", params: { feature_key: 'storage' }
    assert_response :success
    assert_match 'name="plan_feature[limit_value]"', response.body
    refute_match 'name="plan_feature[period]"', response.body
    refute_match 'name="plan_feature[enabled]"', response.body
  end

  test 'GET attach_feature with archived feature_key redirects to picker with alert' do
    @flag.update!(archived_at: Time.current)
    get "/admin/plans/#{@plan.id}/attach_feature", params: { feature_key: 'sso' }
    assert_response :redirect
    follow_redirect!
    assert_match 'no longer available', response.body
  end

  test 'GET attach_feature with already-attached feature_key redirects to picker with alert' do
    get "/admin/plans/#{@plan.id}/attach_feature", params: { feature_key: 'already' }
    assert_response :redirect
    follow_redirect!
    assert_match 'no longer available', response.body
  end

  # Create flow (POST /admin/plans/:id/attach_feature) is exercised in
  # PlansPlanFeatureActionsTest; here we only cover step-1/step-2 rendering.
end
