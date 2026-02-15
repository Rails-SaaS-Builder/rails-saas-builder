# frozen_string_literal: true

require 'test_helper'

class ClientTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set('entitlements.providers.stripe.secret_key', 'sk_test_abc123')
  end

  test 'client returns a Stripe::StripeClient' do
    client = RSB::Entitlements::Stripe.client
    assert_instance_of ::Stripe::StripeClient, client
  end

  test 'reset! clears cached client' do
    client1 = RSB::Entitlements::Stripe.client
    RSB::Entitlements::Stripe.reset!
    client2 = RSB::Entitlements::Stripe.client
    refute_equal client1.object_id, client2.object_id
  end
end
