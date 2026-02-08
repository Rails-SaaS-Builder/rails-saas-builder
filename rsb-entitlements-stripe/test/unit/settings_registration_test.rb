require "test_helper"

class SettingsRegistrationTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
  end

  test "stripe provider is registered" do
    definition = RSB::Entitlements.providers.find(:stripe)
    assert_not_nil definition
    assert_equal :stripe, definition.key
    assert_equal "Stripe", definition.label
  end

  test "stripe provider is not manual_resolution" do
    definition = RSB::Entitlements.providers.find(:stripe)
    refute definition.manual_resolution
  end

  test "stripe provider is refundable" do
    definition = RSB::Entitlements.providers.find(:stripe)
    assert definition.refundable
  end

  test "stripe provider has refund admin action" do
    definition = RSB::Entitlements.providers.find(:stripe)
    assert_includes definition.admin_actions, :refund
  end

  test "enabled setting defaults to false" do
    value = RSB::Settings.get("entitlements.providers.stripe.enabled")
    assert_equal false, value
  end

  test "secret_key setting defaults to empty string" do
    value = RSB::Settings.get("entitlements.providers.stripe.secret_key")
    assert_equal "", value
  end

  test "publishable_key setting defaults to empty string" do
    value = RSB::Settings.get("entitlements.providers.stripe.publishable_key")
    assert_equal "", value
  end

  test "webhook_secret setting defaults to empty string" do
    value = RSB::Settings.get("entitlements.providers.stripe.webhook_secret")
    assert_equal "", value
  end

  test "success_url setting defaults to empty string" do
    value = RSB::Settings.get("entitlements.providers.stripe.success_url")
    assert_equal "", value
  end

  test "cancel_url setting defaults to empty string" do
    value = RSB::Settings.get("entitlements.providers.stripe.cancel_url")
    assert_equal "", value
  end

  test "settings can be updated" do
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_test_123")
    assert_equal "sk_test_123", RSB::Settings.get("entitlements.providers.stripe.secret_key")
  end
end
