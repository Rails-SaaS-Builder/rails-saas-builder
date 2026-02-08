require "test_helper"

class GemLoadingTest < ActiveSupport::TestCase
  test "RSB::Entitlements::Stripe module is defined" do
    assert defined?(RSB::Entitlements::Stripe)
  end

  test "RSB::Entitlements::Stripe::Engine is defined" do
    assert defined?(RSB::Entitlements::Stripe::Engine)
  end

  test "VERSION is set" do
    assert RSB::Entitlements::Stripe::VERSION.present?
  end

  test "configuration is accessible" do
    RSB::Entitlements::Stripe.reset!
    config = RSB::Entitlements::Stripe.configuration
    assert_instance_of RSB::Entitlements::Stripe::Configuration, config
    assert_equal false, config.skip_webhook_verification
  end

  test "reset! clears cached client and configuration" do
    RSB::Entitlements::Stripe.configuration.skip_webhook_verification = true
    RSB::Entitlements::Stripe.reset!
    assert_equal false, RSB::Entitlements::Stripe.configuration.skip_webhook_verification
  end
end
