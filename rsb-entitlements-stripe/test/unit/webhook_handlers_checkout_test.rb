require "test_helper"

class WebhookHandlersCheckoutTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_123")
    RSB::Settings.set("entitlements.providers.stripe.enabled", true)
  end

  # --- checkout.session.completed (payment mode) ---

  test "checkout.session.completed grants entitlement for payment mode" do
    plan = create_test_plan(interval: "one_time", metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing",
      provider_ref: "cs_test_payment",
      provider_data: { "checkout_session_id" => "cs_test_payment", "mode" => "payment" }
    )

    event = build_checkout_completed_event(
      session_id: "cs_test_payment",
      mode: "payment",
      payment_intent: "pi_test_123",
      customer: "cus_test_abc"
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    pr.reload
    assert_equal "approved", pr.status
    assert_not_nil pr.entitlement
    assert_equal "pi_test_123", pr.provider_data["payment_intent_id"]
    assert_equal "cus_test_abc", pr.provider_data["customer_id"]
  end

  test "checkout.session.completed grants entitlement for subscription mode" do
    plan = create_test_plan(interval: "monthly", metadata: { "stripe_price_id" => "price_sub_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing",
      provider_ref: "cs_test_sub",
      provider_data: { "checkout_session_id" => "cs_test_sub", "mode" => "subscription" }
    )

    event = build_checkout_completed_event(
      session_id: "cs_test_sub",
      mode: "subscription",
      subscription: "sub_test_789",
      customer: "cus_test_def"
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    pr.reload
    assert_equal "approved", pr.status
    assert_equal "sub_test_789", pr.provider_ref  # Updated to subscription ID
    assert_equal "sub_test_789", pr.provider_data["subscription_id"]
    assert_equal "sub_test_789", pr.entitlement.provider_ref
  end

  test "checkout.session.completed is idempotent" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing",
      provider_ref: "cs_test_idemp",
      provider_data: { "checkout_session_id" => "cs_test_idemp", "mode" => "payment" }
    )

    event = build_checkout_completed_event(session_id: "cs_test_idemp", mode: "payment")

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    entitlement_id = pr.reload.entitlement_id

    # Second call — should be a no-op
    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    assert_equal entitlement_id, pr.reload.entitlement_id
  end

  test "checkout.session.completed with unknown session is a no-op" do
    event = build_checkout_completed_event(session_id: "cs_unknown", mode: "payment")
    assert_nothing_raised do
      RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    end
  end

  # --- invoice.paid ---

  test "invoice.paid extends subscription entitlement" do
    plan = create_test_plan(interval: "monthly", metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    entitlement.update!(provider_ref: "sub_renewal_test")
    _pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_ref: "sub_renewal_test"
    )

    event = build_invoice_paid_event(subscription_id: "sub_renewal_test")

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal "active", entitlement.status
    assert entitlement.expires_at > Time.current
  end

  # --- invoice.payment_failed ---

  test "invoice.payment_failed stores failure info without revoking" do
    plan = create_test_plan(interval: "monthly", metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    entitlement = requestable.grant_entitlement(plan: plan, provider: "stripe")
    entitlement.update!(provider_ref: "sub_fail_test")
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "approved",
      provider_ref: "sub_fail_test"
    )

    event = build_invoice_failed_event(subscription_id: "sub_fail_test")

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    pr.reload
    assert_equal "approved", pr.status  # NOT changed — still approved
    assert pr.provider_data["failure_message"].present?
  end

  private

  def create_test_requestable
    Organization.create!(name: "Test Org #{SecureRandom.hex(4)}")
  end

  def build_checkout_completed_event(session_id:, mode:, payment_intent: nil, subscription: nil, customer: nil)
    data = {
      "id" => "evt_test_#{SecureRandom.hex(4)}",
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => session_id,
          "mode" => mode,
          "payment_intent" => payment_intent,
          "subscription" => subscription,
          "customer" => customer
        }
      }
    }
    ::Stripe::Event.construct_from(data)
  end

  def build_invoice_paid_event(subscription_id:)
    data = {
      "id" => "evt_test_#{SecureRandom.hex(4)}",
      "type" => "invoice.paid",
      "data" => {
        "object" => {
          "id" => "in_test_#{SecureRandom.hex(4)}",
          "subscription" => subscription_id,
          "lines" => {
            "data" => [{
              "period" => { "end" => 1.month.from_now.to_i }
            }]
          }
        }
      }
    }
    ::Stripe::Event.construct_from(data)
  end

  def build_invoice_failed_event(subscription_id:)
    data = {
      "id" => "evt_test_#{SecureRandom.hex(4)}",
      "type" => "invoice.payment_failed",
      "data" => {
        "object" => {
          "id" => "in_test_#{SecureRandom.hex(4)}",
          "subscription" => subscription_id,
          "last_finalization_error" => {
            "code" => "card_declined",
            "message" => "Your card was declined."
          }
        }
      }
    }
    ::Stripe::Event.construct_from(data)
  end
end
