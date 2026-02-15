# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class WebhookHandlersSubscriptionTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
    RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
    RSB::Settings.set('entitlements.providers.stripe.secret_key', 'sk_test_123')
    RSB::Settings.set('entitlements.providers.stripe.webhook_secret', 'whsec_test_123')
    RSB::Settings.set('entitlements.providers.stripe.enabled', true)
  end

  test 'handle_subscription_updated activates entitlement when status is active' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123', status: 'processing')

    # Create entitlement in pending state
    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'pending'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'active')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'active', entitlement.status
    assert_not_nil entitlement.activated_at
  end

  test 'handle_subscription_updated keeps entitlement active when status is trialing' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'pending'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'trialing')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'active', entitlement.status
  end

  test 'handle_subscription_updated keeps active entitlement when status is past_due' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active',
      activated_at: 1.day.ago
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'past_due')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'active', entitlement.status
  end

  test 'handle_subscription_updated revokes entitlement when status is canceled' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active',
      activated_at: 1.day.ago
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'canceled')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_not_nil entitlement.revoked_at
    assert_equal 'non_renewal', entitlement.revoke_reason
  end

  test 'handle_subscription_updated revokes entitlement when status is unpaid' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'unpaid')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal 'non_renewal', entitlement.revoke_reason
  end

  test 'handle_subscription_updated revokes entitlement when status is incomplete_expired' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'incomplete_expired')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal 'non_renewal', entitlement.revoke_reason
  end

  test 'handle_subscription_updated is idempotent for already active entitlement' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123')

    activated_at = 2.days.ago
    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active',
      activated_at: activated_at
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.updated',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123', status: 'active')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'active', entitlement.status
    assert_equal activated_at.to_i, entitlement.activated_at.to_i
  end

  test 'handle_subscription_deleted revokes entitlement and expires payment request' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123', status: 'approved')

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'active',
      activated_at: 1.day.ago
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.deleted',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_not_nil entitlement.revoked_at
    assert_equal 'non_renewal', entitlement.revoke_reason

    pr.reload
    assert_equal 'expired', pr.status
    assert_not_nil pr.expires_at
  end

  test 'handle_subscription_deleted is idempotent' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(provider_ref: 'sub_test_123', status: 'expired', expires_at: 1.day.ago)

    revoked_at = 2.days.ago
    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      provider_ref: 'sub_test_123',
      status: 'revoked',
      revoked_at: revoked_at,
      revoke_reason: 'non_renewal'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'customer.subscription.deleted',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'sub_test_123')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal revoked_at.to_i, entitlement.revoked_at.to_i
    assert_equal 'non_renewal', entitlement.revoke_reason
  end

  test 'handle_charge_refunded revokes entitlement for one-time payment' do
    plan = create_test_plan(interval: 'one_time')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(
      provider_ref: 'cs_test_123',
      status: 'approved',
      provider_data: { 'payment_intent_id' => 'pi_test_123' }
    )

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      status: 'active',
      activated_at: 1.day.ago
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'charge.refunded',
      data: OpenStruct.new(
        object: OpenStruct.new(
          id: 'ch_test_123',
          payment_intent: 'pi_test_123'
        )
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_not_nil entitlement.revoked_at
    assert_equal 'refund', entitlement.revoke_reason
  end

  test 'handle_charge_refunded skips if payment_intent_id not found' do
    event = OpenStruct.new(
      type: 'charge.refunded',
      data: OpenStruct.new(
        object: OpenStruct.new(
          id: 'ch_test_123',
          payment_intent: 'pi_nonexistent'
        )
      )
    )

    # Should not raise error, just log warning
    assert_nothing_raised do
      RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    end
  end

  test 'handle_charge_refunded skips if no payment_intent on charge' do
    event = OpenStruct.new(
      type: 'charge.refunded',
      data: OpenStruct.new(
        object: OpenStruct.new(id: 'ch_test_123')
      )
    )

    # Should not raise error, just log debug
    assert_nothing_raised do
      RSB::Entitlements::Stripe::WebhookHandlers.handle(event)
    end
  end

  test 'handle_charge_refunded is idempotent' do
    plan = create_test_plan(interval: 'one_time')
    requestable = create_test_requestable
    pr = create_test_payment_request(requestable: requestable, plan: plan, provider_key: 'stripe')
    pr.update!(
      provider_data: { 'payment_intent_id' => 'pi_test_123' },
      status: 'approved'
    )

    revoked_at = 2.days.ago
    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      status: 'revoked',
      revoked_at: revoked_at,
      revoke_reason: 'refund'
    )
    pr.update!(entitlement: entitlement)

    event = OpenStruct.new(
      type: 'charge.refunded',
      data: OpenStruct.new(
        object: OpenStruct.new(payment_intent: 'pi_test_123')
      )
    )

    RSB::Entitlements::Stripe::WebhookHandlers.handle(event)

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal revoked_at.to_i, entitlement.revoked_at.to_i
    assert_equal 'refund', entitlement.revoke_reason
  end

  test 'revoke_entitlement helper sets status, timestamp, and reason' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable

    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      status: 'active'
    )

    RSB::Entitlements::Stripe::WebhookHandlers.send(:revoke_entitlement, entitlement, reason: 'admin')

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_not_nil entitlement.revoked_at
    assert_equal 'admin', entitlement.revoke_reason
  end

  test 'revoke_entitlement is idempotent' do
    plan = create_test_plan(interval: 'monthly')
    requestable = create_test_requestable

    revoked_at = 2.days.ago
    entitlement = RSB::Entitlements::Entitlement.create!(
      plan: plan,
      entitleable: requestable,
      provider: 'stripe',
      status: 'revoked',
      revoked_at: revoked_at,
      revoke_reason: 'admin'
    )

    RSB::Entitlements::Stripe::WebhookHandlers.send(:revoke_entitlement, entitlement, reason: 'refund')

    entitlement.reload
    assert_equal 'revoked', entitlement.status
    assert_equal revoked_at.to_i, entitlement.revoked_at.to_i
    assert_equal 'admin', entitlement.revoke_reason
  end

  private

  def create_test_requestable
    Organization.create!(name: "Test Org #{SecureRandom.hex(4)}")
  end
end
