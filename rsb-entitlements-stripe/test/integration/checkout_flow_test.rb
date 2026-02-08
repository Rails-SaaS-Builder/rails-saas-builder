require "test_helper"

class CheckoutFlowTest < ActiveSupport::TestCase
  setup do
    register_test_stripe_provider
  end

  test "full one-time payment flow: initiate → checkout → webhook → entitlement" do
    plan = create_test_plan(
      interval: "one_time",
      metadata: { "stripe_price_id" => "price_onetime_flow" }
    )
    requestable = Organization.create!(name: "Flow Test Org #{SecureRandom.hex(4)}")

    # 1. Initiate checkout
    mock_session = stub_stripe_checkout_session(id: "cs_flow_onetime", mode: "payment")
    mock_client, recorder = build_mock_stripe_client(checkout_session: mock_session)

    with_mock_stripe_client(mock_client) do
      result = requestable.request_payment(plan: plan, provider: :stripe)

      assert_equal "https://checkout.stripe.com/pay/cs_flow_onetime", result[:redirect_url]
      assert_equal 1, recorder[:checkout_creates].length

      pr = requestable.payment_requests.last
      assert_equal "processing", pr.status
      assert_equal "cs_flow_onetime", pr.provider_ref

      # 2. Simulate webhook: checkout.session.completed
      simulate_stripe_webhook("checkout.session.completed", {
        id: "cs_flow_onetime",
        mode: "payment",
        payment_intent: "pi_flow_123",
        customer: "cus_flow_abc"
      })

      # 3. Verify entitlement granted
      pr.reload
      assert_equal "approved", pr.status
      assert_not_nil pr.entitlement
      assert_equal plan, requestable.current_plan
      assert_equal "pi_flow_123", pr.provider_data["payment_intent_id"]
      assert_equal "cus_flow_abc", pr.provider_data["customer_id"]
    end
  end
end
