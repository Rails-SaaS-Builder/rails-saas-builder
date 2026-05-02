# frozen_string_literal: true

require 'test_helper'

# Cross-gem regression for rsb-admin dispatching to rsb-entitlements admin
# resources.  Per CLAUDE.md these tests live in rails-saas-builder/test/.
#
# Covers:
#   - Test 4: admin dispatch (index pages render with rsb-* theme classes;
#     custom archive/unarchive actions mutate state)
#   - Test 5: admin RBAC (superadmin allowed; non-superadmin denied)
#
# URL conventions for entitlements resources (isolate_namespace RSB::Entitlements
# strips the module prefix from Rails route_key):
#   RSB::Entitlements::Feature.model_name.route_key  => "features"
#   RSB::Entitlements::Plan.model_name.route_key     => "plans"
#   RSB::Entitlements::Subscription.model_name.route_key => "subscriptions"
#
# RBAC resource key used by the custom controllers:
#   FeaturesController => "entitlements_features"
#   PlansController    => "entitlements_plans"
class EntitlementsAdminCrossGemTest < ActionDispatch::IntegrationTest
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    register_all_admin_categories

    # Extend the Billing category with the read-only entitlements resources that
    # the test helper doesn't register (those are only wired via the engine's
    # on_load(:rsb_admin) hook, which fires once at boot and is lost after
    # RSB::Admin.reset! clears the registry between tests).
    RSB::Admin.registry.register_category 'Billing' do
      resource RSB::Entitlements::Subscription,
               icon: 'credit-card',
               actions: %i[index show],
               default_sort: { column: :created_at, direction: :desc } do
        column :id,       link: true
        column :plan_key, sortable: true
        column :status,   formatter: :badge
        column :provider
        column :current_period_end, formatter: :datetime
      end

      resource RSB::Entitlements::UsageCounter,
               icon: 'bar-chart',
               actions: %i[index show],
               default_sort: { column: :updated_at, direction: :desc } do
        column :id,          link: true
        column :feature_key, sortable: true
        column :subject_type
        column :subject_id
        column :consumed
      end

      resource RSB::Entitlements::ProviderEvent,
               icon: 'inbox',
               actions: %i[index show],
               default_sort: { column: :processed_at, direction: :desc } do
        column :id,           link: true
        column :provider,     formatter: :badge
        column :event_id
        column :type
        column :processed_at, formatter: :datetime
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4 — admin dispatch: index pages
  # ---------------------------------------------------------------------------

  test 'GET /admin/features renders index with rsb-* theme classes and feature data' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    create_test_feature(key: 'sso',       kind: 'flag', unit: nil)
    create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')

    get '/admin/features'
    assert_response :success
    assert_match(/rsb-/, response.body, 'expected rsb-* theme classes in admin features index')
    assert_match 'sso',       response.body
    assert_match 'api_calls', response.body
  end

  test 'GET /admin/subscriptions renders index for a subject with an active subscription' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    plan = create_test_plan(key: 'pro')
    org  = Organization.create!(name: 'Acme Admin')
    create_test_subscription(subject: org, plan: plan, status: 'active')

    get '/admin/subscriptions'
    assert_response :success
    assert_match(/rsb-/, response.body, 'expected rsb-* theme classes in subscriptions index')
    assert_match 'pro',    response.body
    assert_match 'active', response.body
  end

  test 'GET /admin/usage_counters renders index after consuming a feature' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    feature = create_test_feature(key: 'api_calls', kind: 'metered', unit: 'count')
    plan    = create_test_plan(key: 'pro')
    attach_test_feature(plan: plan, feature: feature, limit_value: 50, period: 'month')

    org = Organization.create!(name: 'Counter Org')
    create_test_subscription(subject: org, plan: plan)
    org.consume!(:api_calls, amount: 5)

    get '/admin/usage_counters'
    assert_response :success
    assert_match(/rsb-/, response.body)
    assert_match 'api_calls', response.body
  end

  test 'GET /admin/provider_events renders index after processing a webhook' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    plan = create_test_plan(key: 'pro')
    org  = Organization.create!(name: 'Webhook Org')

    RSB::Entitlements::Webhooks.process(
      provider: 'stripe', event_id: "evt_#{SecureRandom.hex(8)}",
      type: 'customer.subscription.updated', payload: { 'v' => 1 }
    ) do
      create_test_subscription(subject: org, plan: plan, provider: 'stripe')
    end

    get '/admin/provider_events'
    assert_response :success
    assert_match(/rsb-/, response.body)
    assert_match(/stripe/i, response.body)
  end

  # ---------------------------------------------------------------------------
  # Test 4 — admin dispatch: custom archive / unarchive actions
  # ---------------------------------------------------------------------------

  test 'POST /admin/features/:id/archive sets archived_at and redirects' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    feature = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
    refute feature.archived_at.present?, 'feature should start un-archived'

    post "/admin/features/#{feature.id}/archive"
    assert_response :redirect

    assert feature.reload.archived_at.present?, 'archive action must set archived_at'
  end

  test 'POST /admin/features/:id/unarchive clears archived_at and redirects' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    feature = create_test_feature(key: 'sso', kind: 'flag', unit: nil)
    feature.update_column(:archived_at, Time.current)
    assert feature.archived_at.present?

    post "/admin/features/#{feature.id}/unarchive"
    assert_response :redirect

    assert_nil feature.reload.archived_at, 'unarchive action must clear archived_at'
  end

  test 'archive + unarchive round-trip leaves feature in un-archived state' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    feature = create_test_feature(key: 'beta', kind: 'flag', unit: nil)

    post "/admin/features/#{feature.id}/archive"
    assert_response :redirect
    assert feature.reload.archived_at.present?

    post "/admin/features/#{feature.id}/unarchive"
    assert_response :redirect
    assert_nil feature.reload.archived_at
  end

  # ---------------------------------------------------------------------------
  # Test 5 — admin RBAC
  # ---------------------------------------------------------------------------

  test 'superadmin can archive features' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    feature = create_test_feature(key: 'new_feature', kind: 'flag', unit: nil)

    post "/admin/features/#{feature.id}/archive"
    assert_response :redirect
    assert feature.reload.archived_at.present?
  end

  test 'non-superadmin without entitlements permission is denied archive access' do
    # Admin with only identity-related permissions — no access to features or
    # entitlements_features resources.
    admin = create_test_admin!(permissions: { 'identities' => ['index'] })
    sign_in_admin(admin)

    feature = create_test_feature(key: 'restricted', kind: 'flag', unit: nil)

    post "/admin/features/#{feature.id}/archive"
    assert_admin_denied

    assert_nil feature.reload.archived_at,
               'archive must not have run for an unauthorized admin'
  end

  test 'non-superadmin without entitlements permission is denied features index' do
    admin = create_test_admin!(permissions: { 'identities' => ['index'] })
    sign_in_admin(admin)

    get '/admin/features'
    assert_admin_denied
  end
end
