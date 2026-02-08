require "test_helper"
require "ostruct"

class PaymentProviderLifecycleTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_123")
    RSB::Settings.set("entitlements.providers.stripe.enabled", true)
  end

  # --- complete! ---

  test "complete! grants entitlement and transitions to approved" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing"
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    provider.complete!

    pr.reload
    assert_equal "approved", pr.status
    assert_not_nil pr.entitlement
    assert_equal plan, requestable.current_plan
  end

  test "complete! is idempotent — no-op if already approved" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing"
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    provider.complete!
    entitlement_id = pr.reload.entitlement_id

    # Second call should be a no-op
    provider.complete!
    assert_equal entitlement_id, pr.reload.entitlement_id
  end

  test "complete! stores subscription_id on entitlement when provided" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing"
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    provider.complete!(subscription_id: "sub_test_456")

    entitlement = pr.reload.entitlement
    assert_equal "sub_test_456", entitlement.provider_ref
  end

  # --- reject! ---

  test "reject! is a no-op" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing"
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    # Should not raise and should not change status
    provider.reject!
    assert_equal "processing", pr.reload.status
  end

  # --- admin_details ---

  test "admin_details returns Stripe-specific data" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe",
      provider_data: {
        "checkout_session_id" => "cs_test_abc",
        "mode" => "subscription",
        "customer_id" => "cus_test_123",
        "subscription_id" => "sub_test_456",
        "payment_intent_id" => "pi_test_789"
      }
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    details = provider.admin_details
    assert_equal "Subscription", details["Mode"]
    assert_equal "cs_test_abc", details["Checkout Session"]
    assert_equal "cus_test_123", details["Stripe Customer"]
    assert_equal "sub_test_456", details["Subscription"]
    assert_equal "pi_test_789", details["Payment Intent"]
  end

  test "admin_details handles empty provider_data" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe",
      provider_data: {}
    )
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    details = provider.admin_details
    assert_equal({}, details)
  end

  # --- refund! ---

  test "refund! creates Stripe refund and revokes entitlement" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_data: {
        "mode" => "payment",
        "payment_intent_id" => "pi_test_refund"
      }
    )
    # Grant entitlement first
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    pr.update!(entitlement: entitlement)

    mock_refund = OpenStruct.new(id: "re_test_123")
    mock_refunds = Object.new
    mock_refunds.define_singleton_method(:create) { |**_| mock_refund }
    mock_v1 = OpenStruct.new(refunds: mock_refunds)
    mock_client = OpenStruct.new(v1: mock_v1)

    with_mock_stripe_client(mock_client) do
      RSB::Entitlements::Stripe::PaymentProvider.new(pr).refund!

      pr.reload
      assert_equal "refunded", pr.status
      assert_equal "re_test_123", pr.provider_data["refund_id"]
    end
  end

  private

  def create_test_requestable
    Organization.create!(name: "Test Org #{SecureRandom.hex(4)}")
  end
end
