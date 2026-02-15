# frozen_string_literal: true

require 'test_helper'

class UsageCounterLedgerTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    register_test_provider(key: :admin)

    @admin = create_test_admin!(superadmin: true)
  end

  # --- Settings Integration ---

  test 'on_plan_change_usage setting is registered and resolvable' do
    value = RSB::Settings.get('entitlements.on_plan_change_usage')
    assert_equal 'continue', value
  end

  test 'on_plan_change_usage setting can be changed at runtime' do
    RSB::Settings.set('entitlements.on_plan_change_usage', 'reset')
    assert_equal 'reset', RSB::Settings.get('entitlements.on_plan_change_usage')
  end

  test 'auto_create_counters setting still works' do
    value = RSB::Settings.get('entitlements.auto_create_counters')
    assert_equal true, value
  end

  # --- Identity + Entitleable Integration ---

  test 'Identity with Entitleable concern can increment usage with period-aware counters' do
    identity = create_test_identity
    plan = create_test_plan(limits: {
                              'api_calls' => { 'limit' => 100, 'period' => 'daily' }
                            })
    grant_test_entitlement(identity, plan: plan)

    identity.increment_usage('api_calls', 10)
    assert_equal 10, identity.usage_counters.for_metric('api_calls').last.current_value
    assert_equal Time.current.strftime('%Y-%m-%d'), identity.usage_counters.for_metric('api_calls').last.period_key
    assert identity.within_limit?('api_calls')
    assert_equal 90, identity.remaining('api_calls')
  end

  test 'Identity can check limits with cumulative metrics' do
    identity = create_test_identity
    plan = create_test_plan(limits: {
                              'projects' => { 'limit' => 5, 'period' => nil }
                            })
    grant_test_entitlement(identity, plan: plan)

    identity.increment_usage('projects', 3)
    counter = identity.usage_counters.for_metric('projects').last
    assert_equal '__cumulative__', counter.period_key
    assert_equal 2, identity.remaining('projects')
  end

  test 'Identity usage_history returns historical records across periods' do
    identity = create_test_identity
    plan = create_test_plan(limits: {
                              'api_calls' => { 'limit' => 100, 'period' => 'daily' }
                            })
    grant_test_entitlement(identity, plan: plan)

    # Create historical records
    RSB::Entitlements::UsageCounter.create!(countable: identity, metric: 'api_calls', period_key: '2026-02-11',
                                            plan: plan, current_value: 50, limit: 100)
    RSB::Entitlements::UsageCounter.create!(countable: identity, metric: 'api_calls', period_key: '2026-02-12',
                                            plan: plan, current_value: 75, limit: 100)

    history = identity.usage_history('api_calls', limit: 10)
    assert history.size >= 2
    # Most recent first
    assert history.first.period_key >= history.last.period_key
  end

  # --- Plan Change Integration ---

  test 'plan upgrade with continue mode carries over usage' do
    RSB::Settings.set('entitlements.on_plan_change_usage', 'continue')

    identity = create_test_identity
    basic = create_test_plan(name: 'Basic', limits: {
                               'api_calls' => { 'limit' => 100, 'period' => 'monthly' }
                             })
    grant_test_entitlement(identity, plan: basic)
    identity.increment_usage('api_calls', 60)

    # Verify setting is still "continue" before plan change
    assert_equal 'continue', RSB::Settings.get('entitlements.on_plan_change_usage')

    pro = create_test_plan(name: 'Pro', limits: {
                             'api_calls' => { 'limit' => 1000, 'period' => 'monthly' }
                           })
    identity.grant_entitlement(plan: pro, provider: 'admin')

    # Usage should carry over
    new_counter = identity.usage_counters.for_metric('api_calls').for_plan(pro).last
    assert_equal 60, new_counter.current_value,
                 'Usage should carry over from Basic plan (continue mode, same period type)'
    assert_equal 1000, new_counter.limit
  end

  test 'plan upgrade with reset mode starts fresh' do
    RSB::Settings.set('entitlements.on_plan_change_usage', 'reset')

    identity = create_test_identity
    basic = create_test_plan(name: 'Basic', limits: {
                               'api_calls' => { 'limit' => 100, 'period' => 'monthly' }
                             })
    grant_test_entitlement(identity, plan: basic)
    identity.increment_usage('api_calls', 60)

    pro = create_test_plan(name: 'Pro', limits: {
                             'api_calls' => { 'limit' => 1000, 'period' => 'monthly' }
                           })
    identity.grant_entitlement(plan: pro, provider: 'admin')

    new_counter = identity.usage_counters.for_metric('api_calls').for_plan(pro).last
    assert_equal 0, new_counter.current_value
    assert_equal 1000, new_counter.limit

    # Old counter preserved
    old_counter = identity.usage_counters.for_metric('api_calls').for_plan(basic).last
    assert_equal 60, old_counter.current_value
  end

  test 'plan change with period type change always creates fresh counter' do
    RSB::Settings.set('entitlements.on_plan_change_usage', 'continue')

    identity = create_test_identity
    daily = create_test_plan(name: 'Daily', limits: {
                               'api_calls' => { 'limit' => 100, 'period' => 'daily' }
                             })
    grant_test_entitlement(identity, plan: daily)
    identity.increment_usage('api_calls', 50)

    monthly = create_test_plan(name: 'Monthly', limits: {
                                 'api_calls' => { 'limit' => 10_000, 'period' => 'monthly' }
                               })
    identity.grant_entitlement(plan: monthly, provider: 'admin')

    new_counter = identity.usage_counters.for_metric('api_calls').for_plan(monthly).last
    assert_equal 0, new_counter.current_value # fresh start on period change
    assert_equal Time.current.strftime('%Y-%m'), new_counter.period_key
  end

  # --- Admin Integration ---

  test 'admin usage monitoring page loads with counter data' do
    sign_in_admin(@admin)

    identity = create_test_identity
    plan = create_test_plan(limits: { 'api_calls' => { 'limit' => 100, 'period' => 'daily' } })
    grant_test_entitlement(identity, plan: plan)
    identity.increment_usage('api_calls', 42)

    get '/admin/usage_counters'
    assert_response :success
    assert_match 'api_calls', response.body
    assert_match '42', response.body
  end

  test 'admin usage monitoring trend page loads' do
    sign_in_admin(@admin)

    identity = create_test_identity
    plan = create_test_plan(limits: { 'api_calls' => { 'limit' => 100, 'period' => 'daily' } })
    RSB::Entitlements::UsageCounter.create!(countable: identity, metric: 'api_calls', period_key: '2026-02-12',
                                            plan: plan, current_value: 50, limit: 100)
    RSB::Entitlements::UsageCounter.create!(countable: identity, metric: 'api_calls', period_key: '2026-02-13',
                                            plan: plan, current_value: 75, limit: 100)

    get '/admin/usage_counters/trend', params: { metric: 'api_calls' }
    assert_response :success
    assert_match '2026-02-12', response.body
    assert_match '2026-02-13', response.body
  end

  test 'admin usage counters page registered in admin registry' do
    registry = RSB::Admin.registry
    billing = registry.categories['Billing']
    assert billing, 'Billing category should exist'

    usage_page = billing.pages.find { |p| p.key == :usage_counters }
    assert usage_page, 'Usage Monitoring page should exist'
    assert_equal 'Usage Monitoring', usage_page.label
  end

  # --- Full End-to-End Flow ---

  test 'complete flow: create plan, grant, increment, upgrade, verify history' do
    identity = create_test_identity
    free = create_test_plan(name: 'Free', limits: {
                              'api_calls' => { 'limit' => 10, 'period' => 'daily' },
                              'projects' => { 'limit' => 2, 'period' => nil }
                            })
    grant_test_entitlement(identity, plan: free)

    # Use free plan
    identity.increment_usage('api_calls', 8)
    identity.increment_usage('projects', 1)

    assert identity.within_limit?('api_calls')
    assert_equal 2, identity.remaining('api_calls')
    assert_equal 1, identity.remaining('projects')

    # Upgrade to pro
    pro = create_test_plan(name: 'Pro', limits: {
                             'api_calls' => { 'limit' => 1000, 'period' => 'monthly' },
                             'projects' => { 'limit' => 50, 'period' => nil },
                             'storage_gb' => { 'limit' => 100, 'period' => nil }
                           })
    identity.grant_entitlement(plan: pro, provider: 'admin')

    # Verify new plan is active
    assert_equal pro, identity.current_plan

    # api_calls: period changed (daily → monthly), should have fresh counter
    assert identity.within_limit?('api_calls')

    # projects: cumulative, should exist under new plan
    projects_counter = identity.usage_counters.for_metric('projects').for_plan(pro).last
    assert_not_nil projects_counter

    # storage_gb: new metric, should have fresh counter
    storage_counter = identity.usage_counters.for_metric('storage_gb').for_plan(pro).last
    assert_not_nil storage_counter
    assert_equal 0, storage_counter.current_value

    # History should have records from both plans
    history = identity.usage_history('api_calls')
    assert history.size >= 1
  end
end
