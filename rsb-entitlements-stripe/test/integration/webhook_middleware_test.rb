require "test_helper"
require "rack/test"

class WebhookMiddlewareTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_test_123")
    RSB::Entitlements::Stripe.configuration.skip_webhook_verification = true
  end

  def app
    inner_app = ->(env) { [200, { "Content-Type" => "text/plain" }, ["inner app"]] }
    RSB::Entitlements::Stripe::WebhookMiddleware.new(inner_app)
  end

  test "passes through non-webhook requests" do
    get "/some-other-path"
    assert_equal 200, last_response.status
    assert_equal "inner app", last_response.body
  end

  test "passes through GET requests to webhook path" do
    get "/rsb/stripe/webhooks"
    assert_equal 200, last_response.status
    assert_equal "inner app", last_response.body
  end

  test "returns 400 for POST without Stripe-Signature header" do
    post "/rsb/stripe/webhooks", "{}", { "CONTENT_TYPE" => "application/json" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "Missing signature"
  end

  test "returns 200 for valid webhook event" do
    event = {
      id: "evt_test_123",
      type: "checkout.session.completed",
      data: { object: { id: "cs_test_abc" } }
    }
    post "/rsb/stripe/webhooks", event.to_json, {
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "test_sig"
    }
    assert_equal 200, last_response.status
    assert_equal "OK", last_response.body
  end

  test "returns 200 for unrecognized event types" do
    event = {
      id: "evt_test_456",
      type: "some.unknown.event",
      data: { object: {} }
    }
    post "/rsb/stripe/webhooks", event.to_json, {
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "test_sig"
    }
    assert_equal 200, last_response.status
  end

  test "returns 422 when handler raises error" do
    event = {
      id: "evt_test_err",
      type: "checkout.session.completed",
      data: { object: { id: "cs_test_err" } }
    }

    # Temporarily replace the handle method to raise an error
    original_method = RSB::Entitlements::Stripe::WebhookHandlers.method(:handle)
    RSB::Entitlements::Stripe::WebhookHandlers.singleton_class.silence_redefinition_of_method(:handle)
    RSB::Entitlements::Stripe::WebhookHandlers.define_singleton_method(:handle) do |_event|
      raise "test error"
    end

    begin
      post "/rsb/stripe/webhooks", event.to_json, {
        "CONTENT_TYPE" => "application/json",
        "HTTP_STRIPE_SIGNATURE" => "test_sig"
      }
      assert_equal 422, last_response.status
      assert_includes last_response.body, "Processing error"
    ensure
      RSB::Entitlements::Stripe::WebhookHandlers.singleton_class.silence_redefinition_of_method(:handle)
      RSB::Entitlements::Stripe::WebhookHandlers.define_singleton_method(:handle, original_method)
    end
  end
end
