require "test_helper"

module RSB
  module Entitlements
    class PaymentRequestTest < ActiveSupport::TestCase
      setup do
        register_test_provider(key: :wire, label: "Wire Transfer")
        @plan = create_test_plan(price_cents: 5000, currency: "usd")
        @org = Organization.create!(name: "Test Org")
      end

      # -- Validations --

      test "valid with all required fields" do
        request = PaymentRequest.new(
          requestable: @org,
          plan: @plan,
          provider_key: "wire",
          status: "pending",
          amount_cents: 5000,
          currency: "usd"
        )
        assert request.valid?
      end

      test "requires requestable" do
        request = PaymentRequest.new(plan: @plan, provider_key: "wire")
        assert_not request.valid?
        assert request.errors[:requestable_type].any? || request.errors[:requestable].any?
      end

      test "requires plan" do
        request = PaymentRequest.new(requestable: @org, provider_key: "wire")
        assert_not request.valid?
        assert request.errors[:plan].any?
      end

      test "requires provider_key" do
        request = PaymentRequest.new(requestable: @org, plan: @plan, provider_key: nil)
        assert_not request.valid?
        assert request.errors[:provider_key].any?
      end

      test "validates provider_key against registered providers" do
        request = PaymentRequest.new(
          requestable: @org, plan: @plan, provider_key: "nonexistent"
        )
        assert_not request.valid?
        assert request.errors[:provider_key].any?
      end

      test "validates status inclusion" do
        request = PaymentRequest.new(
          requestable: @org, plan: @plan, provider_key: "wire", status: "invalid"
        )
        assert_not request.valid?
        assert request.errors[:status].any?
      end

      test "validates amount_cents is >= 0" do
        request = PaymentRequest.new(
          requestable: @org, plan: @plan, provider_key: "wire", amount_cents: -1
        )
        assert_not request.valid?
        assert request.errors[:amount_cents].any?
      end

      test "validates currency presence" do
        request = PaymentRequest.new(
          requestable: @org, plan: @plan, provider_key: "wire", currency: nil
        )
        assert_not request.valid?
        assert request.errors[:currency].any?
      end

      # -- Status enum --

      test "STATUSES contains all valid statuses" do
        expected = %w[pending processing approved rejected expired refunded]
        assert_equal expected, PaymentRequest::STATUSES
      end

      # -- Scopes --

      test "actionable scope returns pending and processing requests" do
        pending_req = create_test_payment_request(requestable: @org, plan: @plan, status: "pending")
        processing_req = create_test_payment_request(
          requestable: @org,
          plan: create_test_plan(slug: "plan-2"),
          status: "processing"
        )
        approved_req = create_test_payment_request(
          requestable: @org,
          plan: create_test_plan(slug: "plan-3"),
          status: "approved"
        )

        actionable = PaymentRequest.actionable
        assert_includes actionable, pending_req
        assert_includes actionable, processing_req
        assert_not_includes actionable, approved_req
      end

      test "for_provider scope filters by provider_key" do
        wire_req = create_test_payment_request(requestable: @org, plan: @plan, provider_key: "wire")
        results = PaymentRequest.for_provider("wire")
        assert_includes results, wire_req
      end

      # -- Associations --

      test "belongs_to requestable (polymorphic)" do
        request = create_test_payment_request(requestable: @org, plan: @plan)
        assert_equal @org, request.requestable
        assert_equal "Organization", request.requestable_type
      end

      test "belongs_to plan" do
        request = create_test_payment_request(requestable: @org, plan: @plan)
        assert_equal @plan, request.plan
      end

      test "belongs_to entitlement (optional)" do
        request = create_test_payment_request(requestable: @org, plan: @plan)
        assert_nil request.entitlement
        assert request.valid?
      end

      # -- Status predicate methods --

      test "pending? returns true when status is pending" do
        request = PaymentRequest.new(status: "pending")
        assert request.pending?
      end

      test "processing? returns true when status is processing" do
        request = PaymentRequest.new(status: "processing")
        assert request.processing?
      end

      test "approved? returns true when status is approved" do
        request = PaymentRequest.new(status: "approved")
        assert request.approved?
      end

      test "rejected? returns true when status is rejected" do
        request = PaymentRequest.new(status: "rejected")
        assert request.rejected?
      end

      test "expired? returns true when status is expired" do
        request = PaymentRequest.new(status: "expired")
        assert request.expired?
      end

      test "refunded? returns true when status is refunded" do
        request = PaymentRequest.new(status: "refunded")
        assert request.refunded?
      end

      test "actionable? returns true for pending and processing" do
        assert PaymentRequest.new(status: "pending").actionable?
        assert PaymentRequest.new(status: "processing").actionable?
        assert_not PaymentRequest.new(status: "approved").actionable?
        assert_not PaymentRequest.new(status: "rejected").actionable?
        assert_not PaymentRequest.new(status: "expired").actionable?
        assert_not PaymentRequest.new(status: "refunded").actionable?
      end

      # -- Defaults --

      test "status defaults to pending" do
        request = PaymentRequest.new
        assert_equal "pending", request.status
      end

      test "amount_cents defaults to 0" do
        request = PaymentRequest.new
        assert_equal 0, request.amount_cents
      end

      test "currency defaults to usd" do
        request = PaymentRequest.new
        assert_equal "usd", request.currency
      end

      # -- Callbacks --

      test "fires after_payment_request_changed callback on status change" do
        fired = false
        RSB::Entitlements.configure do |config|
          config.after_payment_request_changed = ->(req) { fired = true }
        end

        request = create_test_payment_request(requestable: @org, plan: @plan, status: "pending")
        request.update!(status: "processing")
        assert fired, "Expected after_payment_request_changed callback to fire"
      end

      test "does not fire callback when status does not change" do
        fired = false
        RSB::Entitlements.configure do |config|
          config.after_payment_request_changed = ->(_req) { fired = true }
        end

        request = create_test_payment_request(requestable: @org, plan: @plan, status: "pending")
        fired = false # reset after create
        request.update!(admin_note: "Updated note")
        assert_not fired, "Expected callback NOT to fire when status unchanged"
      end
    end
  end
end
