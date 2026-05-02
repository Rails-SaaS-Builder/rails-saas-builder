# frozen_string_literal: true

require 'test_helper'

# Integration tests for the dummy-app-only Entitlements Playground page.
# Verifies the page renders, consume mutates the counter, and overage
# surfaces in the captured events panel via the boot-time hook tap.
class EntitlementsPlaygroundTest < ActionDispatch::IntegrationTest
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)
    # Re-fire the dummy app's playground initializer (it's a config.after_initialize
    # hook, so it ran at boot — but RSB::Admin.reset! cleared the registry).
    RSB::Admin.registry.register_category 'Entitlements' do
      page :entitlements_playground,
           label: 'Playground',
           controller: 'admin/entitlements_playground',
           actions: [
             { key: :index,   label: 'Playground' },
             { key: :consume, label: 'Consume' },
             { key: :release, label: 'Release' },
             { key: :reset,   label: 'Reset' }
           ]
    end

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @plan    = create_test_plan(key: 'pro', name: 'Pro')
    @feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    attach_test_feature(plan: @plan, feature: @feature, limit_value: 5, period: 'month')
    @org = Organization.create!(name: 'Acme Playground')
    create_test_subscription(subject: @org, plan: @plan, status: 'active')
  end

  test 'GET /admin/entitlements_playground renders the page with grants table' do
    get '/admin/entitlements_playground', params: { subject_id: @org.id }
    assert_response :success
    assert_match 'Entitlements Playground', response.body
    assert_match 'api_calls', response.body
    assert_match 'pro', response.body
  end

  test 'POST consume increments the counter and redirects with subject_id preserved' do
    post '/admin/entitlements_playground/consume',
         params: { subject_id: @org.id, feature: 'api_calls', amount: 2 }
    assert_redirected_to "/admin/entitlements_playground?subject_id=#{@org.id}"
    counter = RSB::Entitlements::UsageCounter.find_by(
      subject_type: 'Organization', subject_id: @org.id, feature_key: 'api_calls'
    )
    assert_equal 2, counter.consumed
  end

  test 'POST consume past the limit raises OverLimit and surfaces it in flash events' do
    post '/admin/entitlements_playground/consume',
         params: { subject_id: @org.id, feature: 'api_calls', amount: 999 }
    assert_redirected_to "/admin/entitlements_playground?subject_id=#{@org.id}"
    follow_redirect!
    assert_match 'over_limit_raised', response.body
  end

  test 'POST reset wipes all UsageCounter rows for the subject' do
    @org.consume!(:api_calls, amount: 3)
    assert_equal 1, RSB::Entitlements::UsageCounter.where(subject_id: @org.id).count
    post '/admin/entitlements_playground/reset', params: { subject_id: @org.id }
    assert_redirected_to "/admin/entitlements_playground?subject_id=#{@org.id}"
    assert_equal 0, RSB::Entitlements::UsageCounter.where(subject_id: @org.id).count
  end

  test 'GET /admin/entitlements_playground without subject_id falls back to first Organization' do
    other_org = Organization.create!(name: 'Globex')
    create_test_subscription(subject: other_org, plan: @plan, status: 'active')

    get '/admin/entitlements_playground'
    assert_response :success
    # @subject defaults to @subjects.first, which is the lowest-id Organization
    first_org = Organization.order(:id).first
    assert_match first_org.name, response.body
  end
end
