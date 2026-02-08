require "test_helper"
require "ostruct"

class PaymentProviderInitiateTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_123")
    RSB::Settings.set("entitlements.providers.stripe.success_url", "https://example.com/success?session_id={CHECKOUT_SESSION_ID}")
    RSB::Settings.set("entitlements.providers.stripe.cancel_url", "https://example.com/cancel")
    RSB::Settings.set("entitlements.providers.stripe.enabled", true)
  end

  test "initiate! raises ArgumentError when plan has no stripe_price_id" do
    plan = create_test_plan(metadata: {})
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: "stripe")
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    assert_raises(ArgumentError) { provider.initiate! }
  end

  test "initiate! raises with descriptive message including plan slug" do
    plan = create_test_plan(slug: "pro-monthly", metadata: {})
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: "stripe")
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(pr)

    error = assert_raises(ArgumentError) { provider.initiate! }
    assert_includes error.message, "pro-monthly"
    assert_includes error.message, "stripe_price_id"
  end

  test "checkout_mode returns 'payment' for one_time interval" do
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(nil)
    assert_equal "payment", provider.send(:checkout_mode, "one_time")
  end

  test "checkout_mode returns 'payment' for lifetime interval" do
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(nil)
    assert_equal "payment", provider.send(:checkout_mode, "lifetime")
  end

  test "checkout_mode returns 'subscription' for monthly interval" do
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(nil)
    assert_equal "subscription", provider.send(:checkout_mode, "monthly")
  end

  test "checkout_mode returns 'subscription' for yearly interval" do
    provider = RSB::Entitlements::Stripe::PaymentProvider.new(nil)
    assert_equal "subscription", provider.send(:checkout_mode, "yearly")
  end

  test "initiate! creates checkout session and returns redirect_url" do
    plan = create_test_plan(
      interval: "monthly",
      metadata: { "stripe_price_id" => "price_test_123" }
    )
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: "stripe")

    mock_session = OpenStruct.new(id: "cs_test_abc", url: "https://checkout.stripe.com/pay/cs_test_abc")
    mock_sessions = Object.new
    mock_sessions.define_singleton_method(:create) do |params|
      mock_session
    end

    mock_checkout = OpenStruct.new(sessions: mock_sessions)
    mock_v1 = OpenStruct.new(checkout: mock_checkout)
    mock_client = OpenStruct.new(v1: mock_v1)

    with_mock_stripe_client(mock_client) do
      result = RSB::Entitlements::Stripe::PaymentProvider.new(pr).initiate!

      assert_equal "https://checkout.stripe.com/pay/cs_test_abc", result[:redirect_url]
      pr.reload
      assert_equal "processing", pr.status
      assert_equal "cs_test_abc", pr.provider_ref
      assert_equal "cs_test_abc", pr.provider_data["checkout_session_id"]
      assert_equal "subscription", pr.provider_data["mode"]
    end
  end

  test "initiate! uses 'payment' mode for one_time plan" do
    plan = create_test_plan(
      interval: "one_time",
      metadata: { "stripe_price_id" => "price_onetime_123" }
    )
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: "stripe")

    created_params = nil
    mock_session = OpenStruct.new(id: "cs_test_payment", url: "https://checkout.stripe.com/pay/cs_test_payment")
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

      assert_equal "payment", created_params[:mode]
      refute created_params.key?(:subscription_data)
    end
  end

  test "initiate! includes subscription_data metadata for subscription mode" do
    plan = create_test_plan(
      interval: "yearly",
      metadata: { "stripe_price_id" => "price_yearly_123" }
    )
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: "stripe")

    created_params = nil
    mock_session = OpenStruct.new(id: "cs_test_sub", url: "https://checkout.stripe.com/pay/cs_test_sub")
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

      assert_equal "subscription", created_params[:mode]
      assert created_params[:subscription_data]
      assert created_params[:subscription_data][:metadata]
    end
  end

  private

  def create_test_requestable
    Organization.create!(name: "Test Org #{SecureRandom.hex(4)}")
  end
end
