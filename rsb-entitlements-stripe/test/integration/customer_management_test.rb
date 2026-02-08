require "test_helper"
require "ostruct"

class CustomerManagementTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_123")
    RSB::Settings.set("entitlements.providers.stripe.enabled", true)
    RSB::Settings.set("entitlements.providers.stripe.success_url", "https://example.com/success")
    RSB::Settings.set("entitlements.providers.stripe.cancel_url", "https://example.com/cancel")
  end

  test "checkout stores customer_id on requestable metadata" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_123" })
    requestable = create_test_requestable
    _pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing",
      provider_ref: "cs_cust_test",
      provider_data: { "checkout_session_id" => "cs_cust_test", "mode" => "payment" }
    )

    event = build_checkout_completed_event(
      session_id: "cs_cust_test",
      customer: "cus_stored_123"
    )
    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    requestable.reload
    assert_equal "cus_stored_123", requestable.metadata["stripe_customer_id"]
  end

  test "initiate reuses stored customer_id" do
    plan = create_test_plan(
      interval: "monthly",
      metadata: { "stripe_price_id" => "price_reuse" }
    )
    requestable = create_test_requestable
    # Pre-store customer ID
    requestable.update!(metadata: { "stripe_customer_id" => "cus_returning_456" })

    pr = create_test_payment_request(
      requestable: requestable, plan: plan, provider_key: "stripe"
    )

    created_params = nil
    mock_session = OpenStruct.new(id: "cs_reuse_test", url: "https://checkout.stripe.com/pay/cs_reuse_test")
    mock_sessions = Object.new
    mock_sessions.define_singleton_method(:create) do |params|
      created_params = params
      mock_session
    end
    mock_checkout = OpenStruct.new(sessions: mock_sessions)
    mock_v1 = OpenStruct.new(checkout: mock_checkout)
    mock_client = OpenStruct.new(v1: mock_v1)

    with_mock_stripe_client(mock_client) do
      RSB::Entitlements::Stripe::PaymentProvider.new(pr).initiate!
    end

    assert_equal "cus_returning_456", created_params[:customer]
    refute created_params.key?(:customer_email)
  end

  test "initiate uses billing_email when no customer_id stored" do
    plan = create_test_plan(
      interval: "one_time",
      metadata: { "stripe_price_id" => "price_email" }
    )
    requestable = create_test_requestable_with_email("user@example.com")
    pr = create_test_payment_request(
      requestable: requestable, plan: plan, provider_key: "stripe"
    )

    created_params = nil
    mock_session = OpenStruct.new(id: "cs_email_test", url: "https://checkout.stripe.com/pay/cs_email_test")
    mock_sessions = Object.new
    mock_sessions.define_singleton_method(:create) do |params|
      created_params = params
      mock_session
    end
    mock_checkout = OpenStruct.new(sessions: mock_sessions)
    mock_v1 = OpenStruct.new(checkout: mock_checkout)
    mock_client = OpenStruct.new(v1: mock_v1)

    with_mock_stripe_client(mock_client) do
      RSB::Entitlements::Stripe::PaymentProvider.new(pr).initiate!
    end

    assert_equal "user@example.com", created_params[:customer_email]
    refute created_params.key?(:customer)
  end

  test "customer storage is skipped gracefully if requestable lacks metadata=" do
    plan = create_test_plan(metadata: { "stripe_price_id" => "price_no_meta" })
    requestable = create_test_requestable_without_metadata
    pr = create_test_payment_request(
      requestable: requestable, plan: plan,
      provider_key: "stripe", status: "processing",
      provider_ref: "cs_no_meta",
      provider_data: { "checkout_session_id" => "cs_no_meta", "mode" => "payment" }
    )

    event = build_checkout_completed_event(
      session_id: "cs_no_meta",
      customer: "cus_no_store"
    )

    # Should not raise
    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    assert_equal "approved", pr.reload.status
  end

  private

  def create_test_requestable
    Organization.create!(name: "Test Org #{SecureRandom.hex(4)}", metadata: {})
  end

  def create_test_requestable_with_email(email)
    org = Organization.create!(name: "Test Org with Email #{SecureRandom.hex(4)}", metadata: {})
    # Add billing_email method dynamically
    org.define_singleton_method(:billing_email) { email }
    org
  end

  def create_test_requestable_without_metadata
    # Create a mock object that doesn't respond to metadata=
    org = Organization.create!(name: "Test Org No Metadata #{SecureRandom.hex(4)}", metadata: {})
    # Override the metadata= method to raise NoMethodError
    org.define_singleton_method(:metadata=) do |_value|
      raise NoMethodError, "undefined method `metadata=' for #{self.class}"
    end
    org
  end

  def build_checkout_completed_event(session_id:, customer: nil)
    ::Stripe::Event.construct_from({
      "id" => "evt_#{SecureRandom.hex(4)}",
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => session_id,
          "mode" => "payment",
          "payment_intent" => "pi_#{SecureRandom.hex(4)}",
          "customer" => customer
        }
      }
    })
  end
end
