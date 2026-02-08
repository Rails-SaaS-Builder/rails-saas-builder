require "test_helper"

class StripeSettingsTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
  end

  test "setting and getting stripe secret_key" do
    RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_live_secret")
    assert_equal "sk_live_secret", RSB::Settings.get("entitlements.providers.stripe.secret_key")
  end

  test "setting and getting stripe webhook_secret" do
    RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_live_secret")
    assert_equal "whsec_live_secret", RSB::Settings.get("entitlements.providers.stripe.webhook_secret")
  end

  test "stripe settings coexist with wire settings" do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)

    assert_nothing_raised { RSB::Settings.get("entitlements.providers.stripe.enabled") }
    assert_nothing_raised { RSB::Settings.get("entitlements.providers.wire.enabled") }
  end

  test "stripe enabled defaults to false while wire defaults to true" do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)

    assert_equal false, RSB::Settings.get("entitlements.providers.stripe.enabled")
    assert_equal true, RSB::Settings.get("entitlements.providers.wire.enabled")
  end
end
