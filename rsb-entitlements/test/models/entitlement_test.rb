# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class EntitlementTest < ActiveSupport::TestCase
      setup do
        # Register providers needed for existing tests
        register_test_provider(key: :admin, label: 'Admin')
        register_test_provider(key: :stripe, label: 'Stripe')
        register_test_provider(key: :trial, label: 'Trial')
        RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)

        @org = Organization.create!(name: 'Test Org')
        @plan = create_test_plan(
          features: { 'api' => true },
          limits: { 'projects' => 10 }
        )
      end

      def create_entitlement(**overrides)
        defaults = {
          entitleable: @org,
          plan: @plan,
          status: 'active',
          provider: 'admin',
          activated_at: Time.current
        }
        RSB::Entitlements::Entitlement.create!(defaults.merge(overrides))
      end

      test 'creates a valid entitlement' do
        entitlement = create_entitlement
        assert entitlement.persisted?
      end

      test 'validates status inclusion' do
        entitlement = RSB::Entitlements::Entitlement.new(
          entitleable: @org, plan: @plan, status: 'invalid', provider: 'admin'
        )
        refute entitlement.valid?
        assert_includes entitlement.errors[:status], 'is not included in the list'
      end

      test 'validates provider inclusion' do
        entitlement = RSB::Entitlements::Entitlement.new(
          entitleable: @org, plan: @plan, status: 'active', provider: 'invalid'
        )
        refute entitlement.valid?
        assert entitlement.errors[:provider].any?
      end

      test 'validates revoke_reason inclusion when present' do
        entitlement = RSB::Entitlements::Entitlement.new(
          entitleable: @org, plan: @plan, status: 'revoked', provider: 'admin',
          revoke_reason: 'invalid_reason'
        )
        refute entitlement.valid?
        assert_includes entitlement.errors[:revoke_reason], 'is not included in the list'
      end

      test 'allows nil revoke_reason' do
        entitlement = create_entitlement(revoke_reason: nil)
        assert entitlement.valid?
      end

      test 'activate! sets status to active and activated_at' do
        entitlement = create_entitlement(status: 'pending', activated_at: nil)
        entitlement.activate!

        assert_equal 'active', entitlement.status
        assert_not_nil entitlement.activated_at
      end

      test 'expire! sets status to expired' do
        entitlement = create_entitlement
        entitlement.expire!

        assert_equal 'expired', entitlement.status
      end

      test 'revoke! sets status, revoked_at, and revoke_reason' do
        entitlement = create_entitlement
        entitlement.revoke!(reason: 'refund')

        assert_equal 'revoked', entitlement.status
        assert_not_nil entitlement.revoked_at
        assert_equal 'refund', entitlement.revoke_reason
      end

      test 'active scope returns only active entitlements' do
        active = create_entitlement(status: 'active')
        expired = create_entitlement(status: 'expired')

        result = RSB::Entitlements::Entitlement.active
        assert_includes result, active
        assert_not_includes result, expired
      end

      test 'current scope returns pending and active' do
        pending = create_entitlement(status: 'pending')
        active = create_entitlement(status: 'active')
        expired = create_entitlement(status: 'expired')
        revoked = create_entitlement(status: 'revoked')

        result = RSB::Entitlements::Entitlement.current
        assert_includes result, pending
        assert_includes result, active
        assert_not_includes result, expired
        assert_not_includes result, revoked
      end

      test 'belongs_to entitleable polymorphically' do
        entitlement = create_entitlement
        assert_equal @org, entitlement.entitleable
        assert_equal 'Organization', entitlement.entitleable_type
      end

      test 'belongs_to plan' do
        entitlement = create_entitlement
        assert_equal @plan, entitlement.plan
      end

      test 'fires after_entitlement_changed callback on status change' do
        called_with = nil
        RSB::Entitlements.configuration.after_entitlement_changed = ->(e) { called_with = e }

        entitlement = create_entitlement
        entitlement.revoke!(reason: 'admin')

        assert_equal entitlement, called_with
      ensure
        RSB::Entitlements.configuration.after_entitlement_changed = nil
      end

      test 'does not fire callback when status has not changed' do
        called = false
        RSB::Entitlements.configuration.after_entitlement_changed = ->(_e) { called = true }

        entitlement = create_entitlement
        # Reset the flag after creation (which fires the callback)
        called = false

        # Update a non-status field
        entitlement.update!(provider_ref: 'ref-123')

        refute called
      ensure
        RSB::Entitlements.configuration.after_entitlement_changed = nil
      end

      test 'all valid statuses' do
        %w[pending active expired revoked].each do |status|
          entitlement = RSB::Entitlements::Entitlement.new(
            entitleable: @org, plan: @plan, status: status, provider: 'admin'
          )
          assert entitlement.valid?, "Expected status '#{status}' to be valid"
        end
      end

      test 'all valid revoke_reasons' do
        %w[refund admin chargeback non_renewal upgrade].each do |reason|
          entitlement = RSB::Entitlements::Entitlement.new(
            entitleable: @org, plan: @plan, status: 'revoked', provider: 'admin',
            revoke_reason: reason
          )
          assert entitlement.valid?, "Expected revoke_reason '#{reason}' to be valid"
        end
      end

      # -- Dynamic provider validation --

      test 'provider validates against registered provider keys dynamically' do
        register_test_provider(key: :custom_pay, label: 'Custom Pay')
        plan = create_test_plan
        org = Organization.create!(name: 'Dynamic Provider Org')

        entitlement = RSB::Entitlements::Entitlement.new(
          entitleable: org, plan: plan, provider: 'custom_pay', status: 'pending'
        )
        assert entitlement.valid?, 'Expected entitlement with registered provider to be valid'
      end

      test 'provider rejects unregistered provider key' do
        plan = create_test_plan
        org = Organization.create!(name: 'Bad Provider Org')

        entitlement = RSB::Entitlements::Entitlement.new(
          entitleable: org, plan: plan, provider: 'nonexistent', status: 'pending'
        )
        assert_not entitlement.valid?
        assert entitlement.errors[:provider].any?
      end

      test 'provider accepts all built-in providers when registered' do
        plan = create_test_plan
        org = Organization.create!(name: 'Provider Org')

        %w[wire admin trial stripe].each do |provider_name|
          entitlement = RSB::Entitlements::Entitlement.new(
            entitleable: org, plan: plan, provider: provider_name, status: 'pending'
          )
          assert entitlement.valid?, "Expected provider '#{provider_name}' to be valid"
        end
      end
    end
  end
end
