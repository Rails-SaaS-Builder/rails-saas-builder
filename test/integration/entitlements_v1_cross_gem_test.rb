# frozen_string_literal: true

require 'test_helper'

# Wrapper-level cross-gem regression for rsb-entitlements v1 (TDD-019).
#
# Verifies the gem works correctly when ALL engines are mounted in the meta
# dummy app.  Per CLAUDE.md these tests live in rails-saas-builder/test/, not
# inside any single gem's test/ dir.
#
# RSB::Entitlements::TestHelper automatically calls RSB::Entitlements.reset!
# in before_setup and after_teardown, so hook subscribers registered in one
# test never bleed into the next.
class EntitlementsV1CrossGemTest < ActiveSupport::TestCase
  include RSB::Entitlements::TestHelper
  include RSB::Settings::TestHelper

  setup do
    register_all_settings
    register_all_admin_categories
  end

  # ---------------------------------------------------------------------------
  # Test 1 — engine boot
  # ---------------------------------------------------------------------------

  test 'meta dummy app boots all engines without errors' do
    # eager_load! triggers full autoload of every engine + the host.  If any
    # cross-gem reference is broken (e.g., admin controllers referencing a
    # removed v0 class), this raises here.
    assert_nothing_raised { Rails.application.eager_load! }

    assert defined?(RSB::Settings::Engine),      'RSB::Settings::Engine should be loaded'
    assert defined?(RSB::Auth::Engine),          'RSB::Auth::Engine should be loaded'
    assert defined?(RSB::Admin::Engine),         'RSB::Admin::Engine should be loaded'
    assert defined?(RSB::Entitlements::Engine),  'RSB::Entitlements::Engine should be loaded'
  end

  test 'rsb-entitlements settings schema is registered (intentionally empty in v1)' do
    assert_includes RSB::Settings.registry.categories, 'entitlements',
                    'entitlements schema must be registered even though it is empty in v1'
  end

  test 'rsb-admin registers an entitlements category from the on_load hook (or test helper)' do
    # The test helper registers resources under "Billing"; the engine on_load
    # hook (which fires only at boot) uses "Entitlements".  Either name is
    # acceptable — what matters is that Feature and Plan are accessible.
    cat = RSB::Admin.registry.categories.values.find do |c|
      %w[Entitlements Billing].include?(c.name)
    end
    assert cat, 'expected an Entitlements/Billing admin category registered for rsb-entitlements'

    route_keys = cat.resources.map(&:route_key)
    assert_includes route_keys, 'features', 'expected features resource registered in admin'
    assert_includes route_keys, 'plans',    'expected plans resource registered in admin'
  end

  # ---------------------------------------------------------------------------
  # Test 2 — settings / Subject mixin resolves grant
  # ---------------------------------------------------------------------------

  test 'declared Feature/Plan/PlanFeature/Subscription resolves via Subject#grant_for' do
    feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    plan    = create_test_plan(key: 'pro')
    attach_test_feature(plan: plan, feature: feature, limit_value: 100, period: 'month')

    org = Organization.create!(name: 'Acme A')
    create_test_subscription(subject: org, plan: plan)

    grant = org.grant_for(:api_calls)
    refute_nil grant, 'grant_for should return a hash for an entitled feature'
    assert_equal 'pro',   grant[:plan_key]
    assert_equal 100,     grant[:limit]
    assert_equal 'month', grant[:period]
    assert_equal 100,     org.remaining_for(:api_calls)
  end

  # ---------------------------------------------------------------------------
  # Test 3 — Subject#consume! end-to-end on a host model
  # ---------------------------------------------------------------------------

  test 'Organization including Subject supports consume! and exhausts grant correctly' do
    feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    plan    = create_test_plan(key: 'pro')
    attach_test_feature(plan: plan, feature: feature, limit_value: 5, period: 'month')

    org = Organization.create!(name: 'Acme B')
    create_test_subscription(subject: org, plan: plan)

    org.consume!(:api_calls) # 1 consumed
    org.consume!(:api_calls, amount: 2)  # 3 consumed
    assert_equal 2, org.remaining_for(:api_calls)

    org.consume!(:api_calls, amount: 2)  # 5 consumed — exhausted
    assert_equal 0, org.remaining_for(:api_calls)

    assert_raises(RSB::Entitlements::OverLimit) { org.consume!(:api_calls) }
  end

  test 'Subject without an active subscription raises OverLimit on consume!' do
    create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    org = Organization.create!(name: 'Acme C')

    assert_raises(RSB::Entitlements::OverLimit) { org.consume!(:api_calls) }
    refute org.entitled_to?(:api_calls)
  end

  # ---------------------------------------------------------------------------
  # Test 6 — hook firing across gem boundaries
  # ---------------------------------------------------------------------------

  test ':plan_changed hook subscribed from host fires when Subscriptions.sync! mutates plan_key' do
    free_plan = create_test_plan(key: 'free')
    pro_plan  = create_test_plan(key: 'pro')

    captured = []
    RSB::Entitlements.on(:plan_changed) do |sub, from, to|
      captured << { sub_id: sub.id, from: from, to: to }
    end

    org  = Organization.create!(name: 'Acme D')
    psid = "manual_#{SecureRandom.hex(8)}"

    create_test_subscription(subject: org, plan: free_plan, provider_subscription_id: psid)
    assert_empty captured, 'no :plan_changed hook on first create'

    sub = create_test_subscription(subject: org, plan: pro_plan, provider_subscription_id: psid)
    assert_equal 1, captured.size
    assert_equal sub.id,  captured.first[:sub_id]
    assert_equal 'free',  captured.first[:from]
    assert_equal 'pro',   captured.first[:to]
  end

  test ':overage_blocked hook fires when consume! is rejected past the limit' do
    feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    plan    = create_test_plan(key: 'pro')
    attach_test_feature(plan: plan, feature: feature, limit_value: 1, period: 'month')

    captured = []
    RSB::Entitlements.on(:overage_blocked) { |s, k, a| captured << [s.id, k.to_s, a] }

    org = Organization.create!(name: 'Acme E')
    create_test_subscription(subject: org, plan: plan)

    org.consume!(:api_calls) # exhausts grant
    assert_raises(RSB::Entitlements::OverLimit) { org.consume!(:api_calls) }

    assert_equal 1, captured.size
    assert_equal [org.id, 'api_calls', 1], captured.first
  end

  # ---------------------------------------------------------------------------
  # Test 7 — webhook idempotency end-to-end
  # ---------------------------------------------------------------------------

  test 'Webhooks.process is idempotent: same (provider, event_id) runs block exactly once' do
    plan = create_test_plan(key: 'pro')
    org  = Organization.create!(name: 'Acme F')

    invoked = 0
    block = lambda do
      invoked += 1
      RSB::Entitlements::Subscriptions.sync!(
        provider: 'stripe', provider_subscription_id: 'sub_idempotent_test',
        subject: org, plan_key: plan.key, status: 'active',
        current_period_start: Time.current, current_period_end: 1.month.from_now
      )
    end

    result_a = RSB::Entitlements::Webhooks.process(
      provider: 'stripe', event_id: 'evt_idem_001',
      type: 'customer.subscription.updated', payload: { 'v' => 1 }, &block
    )
    result_b = RSB::Entitlements::Webhooks.process(
      provider: 'stripe', event_id: 'evt_idem_001',
      type: 'customer.subscription.updated', payload: { 'v' => 1 }, &block
    )

    assert_equal :processed,         result_a
    assert_equal :already_processed, result_b
    assert_equal 1, invoked, 'block should run exactly once for duplicate event_id'

    assert_equal 1,
                 RSB::Entitlements::Subscription.where(
                   provider: 'stripe',
                   provider_subscription_id: 'sub_idempotent_test'
                 ).count,
                 'subscription row should be created exactly once'

    assert_equal 1,
                 RSB::Entitlements::ProviderEvent.where(
                   provider: 'stripe',
                   event_id: 'evt_idem_001'
                 ).count,
                 'provider_events row should be created exactly once'
  end
end
