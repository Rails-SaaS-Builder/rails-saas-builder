# frozen_string_literal: true

# Security Test: Entitlement Tampering Prevention
#
# Attack vectors prevented:
# - Client-side grant/revoke of entitlements
# - Payment request state manipulation
# - Duplicate payment request exploitation
# - Unauthorized admin entitlement actions
#
# Covers: SRS-016 US-018 (Entitlement Tampering), US-019 (Admin Action Authorization)

require 'test_helper'

class EntitlementsTamperingTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    Rails.cache.clear

    @identity = create_test_identity
    @credential = create_test_credential(identity: @identity, email: 'entitlement-test@example.com')
    @plan = create_test_plan(name: 'Pro', slug: 'pro')
  end

  # --- US-018: No public route grants entitlements ---

  test 'no auth route can trigger entitlement grant' do
    # Verify that auth routes do not grant entitlements even when plan_id is submitted
    # These routes must be protected against client-side entitlement injection
    auth_routes = [
      [:post, '/auth/session', { identifier: 'nobody@example.com', password: 'pass', plan_id: @plan.id }],
      [:post, '/auth/registration', { email: 'nobody2@example.com', password: 'pass', plan_id: @plan.id }],
      [:post, '/auth/password_resets', { email: 'nobody@example.com', plan_id: @plan.id }]
    ]

    entitlements_before = RSB::Entitlements::Entitlement.count

    auth_routes.each do |method, path, params|
      send(method, path, params: params)
    end

    # No entitlement should have been granted
    assert_equal entitlements_before, RSB::Entitlements::Entitlement.count,
                 'No auth route must be able to grant entitlements'
  end

  test 'entitlement-related actions not exposed via auth routes' do
    # Verify no controller action in rsb-auth exposes entitlement granting
    auth_controller_actions = RSB::Auth::Engine.routes.routes.map do |r|
      r.defaults[:action]
    end.compact.uniq

    entitlement_related = auth_controller_actions.select do |a|
      a.include?('entitlement') || a.include?('grant') || a.include?('plan')
    end

    assert_empty entitlement_related,
                 "Auth routes must not expose entitlement-related actions: #{entitlement_related}"
  end

  # --- US-018: Payment request state guards ---

  test 'payment request actionable? check prevents re-approval' do
    request = create_test_payment_request(
      requestable: @identity,
      plan: @plan
    )

    # Approve the request (mark as processing first, then complete)
    request.update_columns(status: 'processing')
    definition = RSB::Entitlements.providers.find(:wire)
    definition.provider_class.new(request).complete!

    # Try to approve again — must not be actionable
    assert_not request.reload.actionable?,
               'Completed payment request must not be actionable'
  end

  # --- US-018: Duplicate payment request prevention ---

  test 'duplicate concurrent payment requests are prevented by DB unique index' do
    create_test_payment_request(
      requestable: @identity,
      plan: @plan
    )

    # Second request for same requestable + plan should be rejected at DB level
    exception_raised = false
    begin
      RSB::Entitlements::PaymentRequest.create!(
        requestable: @identity,
        plan: @plan,
        provider_key: 'wire',
        amount_cents: 1000,
        currency: 'usd',
        provider_data: {},
        metadata: {}
      )
    rescue ActiveRecord::RecordNotUnique
      exception_raised = true
    end
    assert exception_raised, 'Duplicate payment request must be rejected by unique index'
  end

  # --- US-019: Admin entitlement action authorization ---

  test 'admin with only show permission cannot grant entitlements' do
    read_only_admin = create_test_admin!(permissions: {
                                           'entitlements' => %w[index show]
                                         })
    sign_in_admin(read_only_admin)

    entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @identity,
      plan: @plan,
      status: 'active',
      provider: 'wire',
      activated_at: Time.current
    )

    post "/admin/entitlements/#{entitlement.id}/grant"
    assert_admin_forbidden_page
  end

  test 'admin with only show permission cannot approve payment requests' do
    read_only_admin = create_test_admin!(permissions: {
                                           'payment_requests' => %w[index show]
                                         })
    sign_in_admin(read_only_admin)

    request = create_test_payment_request(
      requestable: @identity,
      plan: @plan
    )

    post "/admin/payment_requests/#{request.id}/approve"
    assert_admin_forbidden_page
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
