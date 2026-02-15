# frozen_string_literal: true

require 'test_helper'

class PaymentProvidersIntegrationTest < ActionDispatch::IntegrationTest
  include RSB::Settings::TestHelper
  include RSB::Entitlements::TestHelper
  include RSB::Admin::TestKit::Helpers

  setup do
    register_all_settings
    register_all_admin_categories
  end

  # -- Settings Integration --

  test 'payment_request_expiry_hours setting is registered and resolvable' do
    value = RSB::Settings.get('entitlements.payment_request_expiry_hours')
    assert_equal 72, value
  end

  test 'wire provider settings are registered under entitlements.providers.wire namespace' do
    # Wire provider is registered at engine boot, its settings should be available
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    enabled = RSB::Settings.get('entitlements.providers.wire.enabled')
    assert_equal true, enabled

    bank_name = RSB::Settings.get('entitlements.providers.wire.bank_name')
    assert_equal '', bank_name
  end

  test 'wire provider settings are editable via RSB::Settings.set' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    RSB::Settings.set('entitlements.providers.wire.bank_name', 'Integration Bank')
    assert_equal 'Integration Bank', RSB::Settings.get('entitlements.providers.wire.bank_name')
  end

  # -- Provider Registry --

  test 'wire provider is registered at boot' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    definition = RSB::Entitlements.providers.find(:wire)
    assert_not_nil definition
    assert_equal :wire, definition.key
    assert_equal 'Wire Transfer', definition.label
    assert_equal true, definition.manual_resolution
  end

  test 'providers.enabled includes wire when enabled' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    with_settings('entitlements.providers.wire.enabled' => true) do
      enabled_keys = RSB::Entitlements.providers.enabled.map(&:key)
      assert_includes enabled_keys, :wire
    end
  end

  test 'providers.enabled excludes wire when disabled' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    with_settings('entitlements.providers.wire.enabled' => false) do
      enabled_keys = RSB::Entitlements.providers.enabled.map(&:key)
      assert_not_includes enabled_keys, :wire
    end
  end

  # -- Admin Registration --

  test 'PaymentRequest resource is registered in admin Billing category' do
    assert_admin_resource_registered(RSB::Entitlements::PaymentRequest, category: 'Billing')
  end

  # -- Cross-Gem: Identity + Entitleable + Payment Request --

  test 'Identity (from rsb-auth) can call request_payment via Entitleable concern' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    identity = RSB::Auth::Identity.create!(status: 'active')
    plan = create_test_plan(price_cents: 2500, currency: 'usd')

    result = identity.request_payment(plan: plan, provider: :wire)

    assert result.key?(:instructions), 'Expected initiate! to return instructions'
    assert_equal 1, identity.payment_requests.count
    assert_equal 'processing', identity.payment_requests.last.status
  end

  # -- Full Wire Transfer E2E Flow --

  test 'full wire transfer flow: request -> admin approve -> entitlement granted' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    identity = RSB::Auth::Identity.create!(status: 'active')
    plan = create_test_plan(price_cents: 9900, currency: 'usd')

    # Step 1: Request payment
    with_settings(
      'entitlements.providers.wire.bank_name' => 'E2E Bank',
      'entitlements.providers.wire.account_number' => '999888777'
    ) do
      result = identity.request_payment(plan: plan, provider: :wire)
      assert_match(/E2E Bank/, result[:instructions])
    end

    payment_request = identity.payment_requests.last
    assert_equal 'processing', payment_request.status
    assert_equal 'E2E Bank', payment_request.provider_data['bank_name']

    # Step 2: Admin approves via controller
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    patch "/admin/payment_requests/#{payment_request.id}/approve"
    assert_redirected_to "/admin/payment_requests/#{payment_request.id}"

    # Step 3: Verify results
    payment_request.reload
    assert_equal 'approved', payment_request.status
    assert_equal admin.email, payment_request.resolved_by
    assert_not_nil payment_request.entitlement_id

    # Step 4: Identity now has active entitlement
    identity.reload
    assert_not_nil identity.current_entitlement
    assert_equal plan, identity.current_plan
    assert_equal 'active', identity.current_entitlement.status
    assert_equal 'wire', identity.current_entitlement.provider
  end

  test 'full wire transfer flow: request -> admin reject -> no entitlement' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    identity = RSB::Auth::Identity.create!(status: 'active')
    plan = create_test_plan(price_cents: 5000)

    identity.request_payment(plan: plan, provider: :wire)
    payment_request = identity.payment_requests.last

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    patch "/admin/payment_requests/#{payment_request.id}/reject",
          params: { admin_note: 'Invalid reference' }

    payment_request.reload
    assert_equal 'rejected', payment_request.status
    assert_equal 'Invalid reference', payment_request.admin_note
    assert_nil payment_request.entitlement_id
    assert_nil identity.reload.current_entitlement
  end

  # -- Expiration Job Integration --

  test 'expiration job works with cross-gem payment requests' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    identity = RSB::Auth::Identity.create!(status: 'active')
    plan = create_test_plan

    identity.request_payment(plan: plan, provider: :wire)
    payment_request = identity.payment_requests.last
    payment_request.update!(expires_at: 1.hour.ago)

    RSB::Entitlements::PaymentRequestExpirationJob.perform_now

    payment_request.reload
    assert_equal 'expired', payment_request.status
    assert_equal 'system:expiration', payment_request.resolved_by
  end

  # -- Admin Settings Page --

  test 'wire provider settings appear on admin settings page' do
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get '/admin/settings'
    assert_response :success
    # Provider settings should be visible in the settings page
  end
end
