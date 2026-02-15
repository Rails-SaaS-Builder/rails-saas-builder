# frozen_string_literal: true

require 'test_helper'

class StripeProviderRegistrationTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
  end

  test 'stripe provider is registered in ProviderRegistry' do
    definition = RSB::Entitlements.providers.find(:stripe)
    assert_not_nil definition
    assert_equal :stripe, definition.key
    assert_equal 'Stripe', definition.label
    assert_equal RSB::Entitlements::Stripe::PaymentProvider, definition.provider_class
  end

  test 'stripe provider coexists with wire provider' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)

    keys = RSB::Entitlements.providers.keys
    assert_includes keys, :stripe
    assert_includes keys, :wire
  end

  test 'stripe provider settings accessible via RSB::Settings' do
    assert_equal false, RSB::Settings.get('entitlements.providers.stripe.enabled')
    assert_equal '', RSB::Settings.get('entitlements.providers.stripe.secret_key')
    assert_equal '', RSB::Settings.get('entitlements.providers.stripe.webhook_secret')
    assert_equal '', RSB::Settings.get('entitlements.providers.stripe.success_url')
    assert_equal '', RSB::Settings.get('entitlements.providers.stripe.cancel_url')
  end

  test 'stripe provider appears in for_select when enabled' do
    RSB::Settings.set('entitlements.providers.stripe.secret_key', 'sk_test_123')
    RSB::Settings.set('entitlements.providers.stripe.webhook_secret', 'whsec_test_123')
    RSB::Settings.set('entitlements.providers.stripe.enabled', true)

    select_options = RSB::Entitlements.providers.for_select
    stripe_option = select_options.find { |_label, key| key == 'stripe' }
    assert_not_nil stripe_option
    assert_equal 'Stripe', stripe_option.first
  end

  test 'stripe provider is not in enabled list when disabled' do
    RSB::Settings.set('entitlements.providers.stripe.enabled', false)

    enabled_keys = RSB::Entitlements.providers.enabled.map(&:key)
    refute_includes enabled_keys, :stripe
  end

  test 'stripe provider definition has correct attributes' do
    definition = RSB::Entitlements.providers.find(:stripe)
    refute definition.manual_resolution
    assert definition.refundable
    assert_includes definition.admin_actions, :refund
  end
end
