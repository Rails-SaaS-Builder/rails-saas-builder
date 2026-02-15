# frozen_string_literal: true

require 'test_helper'

class SubscriptionFlowTest < ActiveSupport::TestCase
  setup do
    register_test_stripe_provider
  end

  test 'full subscription flow: initiate → checkout → renewal → cancel' do
    plan = create_test_plan(
      interval: 'monthly',
      metadata: { 'stripe_price_id' => 'price_sub_flow' }
    )
    requestable = Organization.create!(name: "Sub Flow Org #{SecureRandom.hex(4)}")

    # 1. Initiate checkout
    mock_session = stub_stripe_checkout_session(id: 'cs_flow_sub', mode: 'subscription')
    mock_client, _recorder = build_mock_stripe_client(checkout_session: mock_session)

    with_mock_stripe_client(mock_client) do
      requestable.request_payment(plan: plan, provider: :stripe)
    end

    pr = requestable.payment_requests.last
    assert_equal 'processing', pr.status

    # 2. Checkout completed
    simulate_stripe_webhook('checkout.session.completed', {
                              id: 'cs_flow_sub',
                              mode: 'subscription',
                              subscription: 'sub_flow_789',
                              customer: 'cus_flow_sub'
                            })

    pr.reload
    assert_equal 'approved', pr.status
    assert_equal 'sub_flow_789', pr.provider_ref
    entitlement = pr.entitlement
    assert_not_nil entitlement
    assert_equal 'sub_flow_789', entitlement.provider_ref

    # 3. Subscription renewal (invoice.paid)
    simulate_stripe_webhook('invoice.paid', {
                              id: 'in_renewal_123',
                              subscription: 'sub_flow_789',
                              lines: { data: [{ period: { 'end' => 2.months.from_now.to_i } }] }
                            })

    entitlement.reload
    assert_equal 'active', entitlement.status
    assert entitlement.expires_at > 1.month.from_now

    # 4. Subscription deleted
    simulate_stripe_webhook('customer.subscription.deleted', {
                              id: 'sub_flow_789',
                              status: 'canceled'
                            })

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal 'non_renewal', entitlement.revoke_reason
    assert_equal 'expired', pr.reload.status
  end

  test 'payment failure does not revoke entitlement' do
    plan = create_test_plan(
      interval: 'monthly',
      metadata: { 'stripe_price_id' => 'price_fail_flow' }
    )
    requestable = Organization.create!(name: "Fail Flow Org #{SecureRandom.hex(4)}")
    entitlement = requestable.grant_entitlement(plan: plan, provider: 'stripe')
    entitlement.update!(provider_ref: 'sub_fail_flow')
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: 'stripe', status: 'approved',
      provider_ref: 'sub_fail_flow'
    )

    simulate_stripe_webhook('invoice.payment_failed', {
                              id: 'in_fail_123',
                              subscription: 'sub_fail_flow',
                              last_finalization_error: { code: 'card_declined', message: 'Declined' }
                            })

    assert_equal 'active', entitlement.reload.status
    assert_equal 'card_declined', pr.reload.provider_data['failure_code']
  end
end
