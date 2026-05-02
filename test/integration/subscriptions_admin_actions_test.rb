# frozen_string_literal: true

require 'test_helper'

# Integration tests for the manual-subscription admin flows added in TDD-019
# follow-up: GET /admin/subscriptions/new, POST /admin/subscriptions (manual
# provider auto-assigned), POST /admin/subscriptions/:id/cancel.
class SubscriptionsAdminActionsTest < ActionDispatch::IntegrationTest
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    # Re-fire the entitlements admin_hooks initializer so the registry knows
    # about the SubscriptionsController routing introduced in this fix.
    RSB::Admin.reset!
    ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @plan = create_test_plan(key: 'pro', name: 'Pro')
    @org  = Organization.create!(name: 'Acme Manual')
  end

  test 'GET /admin/subscriptions/new renders the form with the New button on index' do
    get '/admin/subscriptions'
    assert_response :success
    assert_match '+ New manual subscription', response.body

    get '/admin/subscriptions/new'
    assert_response :success
    # Form fields present
    assert_match 'name="subscription[subject_type]"', response.body
    assert_match 'name="subscription[subject_id]"', response.body
    assert_match 'name="subscription[plan_key]"', response.body
    assert_match 'pro', response.body, 'expected the Pro plan in the dropdown'
  end

  test 'POST /admin/subscriptions creates a manual subscription with auto provider id' do
    assert_difference -> { RSB::Entitlements::Subscription.count }, 1 do
      post '/admin/subscriptions', params: {
        subscription: {
          subject_type: 'Organization',
          subject_id: @org.id,
          plan_key: 'pro',
          status: 'active',
          current_period_start: Time.current.iso8601,
          current_period_end: 1.year.from_now.iso8601,
          cancel_at_period_end: '0'
        }
      }
    end

    sub = RSB::Entitlements::Subscription.last
    assert_redirected_to "/admin/subscriptions/#{sub.id}"
    assert_equal 'manual', sub.provider
    assert_match(/\Amanual_/, sub.provider_subscription_id)
    assert_equal @org.id, sub.subject_id
    assert_equal 'Organization', sub.subject_type
    assert_equal 'pro', sub.plan_key
    assert_equal 'active', sub.status
  end

  test 'POST /admin/subscriptions with unknown subject redirects with alert' do
    post '/admin/subscriptions', params: {
      subscription: {
        subject_type: 'Organization',
        subject_id: 999_999,
        plan_key: 'pro',
        status: 'active',
        current_period_start: Time.current.iso8601,
        current_period_end: 1.year.from_now.iso8601
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_match 'No Organization found with id 999999', response.body
  end

  test 'POST /admin/subscriptions/:id/cancel cancels an active subscription' do
    sub = create_test_subscription(subject: @org, plan: @plan, status: 'active')

    post "/admin/subscriptions/#{sub.id}/cancel"
    assert_redirected_to "/admin/subscriptions/#{sub.id}"

    sub.reload
    assert_equal 'canceled', sub.status
    assert_not_nil sub.canceled_at
  end

  test 'POST /admin/subscriptions/:id/cancel rejects already-canceled subscription' do
    sub = create_test_subscription(subject: @org, plan: @plan, status: 'active')
    # First cancel succeeds
    post "/admin/subscriptions/#{sub.id}/cancel"
    sub.reload
    assert_equal 'canceled', sub.status

    # Second attempt should be rejected
    post "/admin/subscriptions/#{sub.id}/cancel"
    assert_response :redirect
    follow_redirect!
    assert_match 'Cannot cancel a subscription with status canceled', response.body
  end
end
