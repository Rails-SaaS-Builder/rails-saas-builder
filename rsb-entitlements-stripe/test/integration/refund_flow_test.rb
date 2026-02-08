require "test_helper"

class RefundFlowTest < ActiveSupport::TestCase
  setup do
    register_test_stripe_provider
  end

  test "admin refund: creates Stripe refund and revokes entitlement" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_refund" })
    requestable = Organization.create!(name: "Refund Org #{SecureRandom.hex(4)}")
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_data: { "mode" => "payment", "payment_intent_id" => "pi_refund_flow" }
    )
    pr.update!(entitlement: entitlement)

    mock_client, recorder = build_mock_stripe_client

    with_mock_stripe_client(mock_client) do
      RSB::Entitlements::Stripe::PaymentProvider.new(pr).refund!
    end

    assert_equal 1, recorder[:refund_creates].length
    assert_equal "pi_refund_flow", recorder[:refund_creates].first[:payment_intent]
    assert_equal "refunded", pr.reload.status
    assert pr.provider_data["refund_id"].present?
  end

  test "subscription refund: cancels subscription and creates refund" do
    plan = create_test_plan(interval: "monthly", metadata: { "stripe_price_id" => "price_sub_refund" })
    requestable = Organization.create!(name: "Sub Refund Org #{SecureRandom.hex(4)}")
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_data: {
        "mode" => "subscription",
        "subscription_id" => "sub_refund_flow",
        "payment_intent_id" => "pi_sub_refund"
      }
    )
    pr.update!(entitlement: entitlement)

    mock_client, recorder = build_mock_stripe_client

    with_mock_stripe_client(mock_client) do
      RSB::Entitlements::Stripe::PaymentProvider.new(pr).refund!
    end

    assert_equal 1, recorder[:subscription_cancels].length
    assert_equal "sub_refund_flow", recorder[:subscription_cancels].first
    assert_equal 1, recorder[:refund_creates].length
    assert_equal "refunded", pr.reload.status
  end

  test "charge.refunded webhook revokes entitlement" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_refund_wh" })
    requestable = Organization.create!(name: "Refund WH Org #{SecureRandom.hex(4)}")
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_data: { "payment_intent_id" => "pi_wh_refund", "mode" => "payment" }
    )
    pr.update!(entitlement: entitlement)

    simulate_stripe_webhook("charge.refunded", {
      id: "ch_test_refund",
      payment_intent: "pi_wh_refund",
      refunds: { data: [{ id: "re_test_wh" }] }
    })

    entitlement.reload
    assert_equal "revoked", entitlement.status
    assert_equal "refund", entitlement.revoke_reason
  end
end
