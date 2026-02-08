require "test_helper"

module RSB
  module Entitlements
    class PaymentRequestExpirationJobTest < ActiveSupport::TestCase
      setup do
        register_test_provider(key: :wire, label: "Wire Transfer")
        @plan = create_test_plan
        @org = Organization.create!(name: "Expiration Job Org")
      end

      test "expires pending requests past expires_at" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "pending",
          expires_at: 1.hour.ago
        )

        PaymentRequestExpirationJob.perform_now

        request.reload
        assert_equal "expired", request.status
        assert_equal "system:expiration", request.resolved_by
        assert_not_nil request.resolved_at
      end

      test "expires processing requests past expires_at" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "processing",
          expires_at: 1.hour.ago
        )

        PaymentRequestExpirationJob.perform_now

        request.reload
        assert_equal "expired", request.status
      end

      test "does not expire requests with future expires_at" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "pending",
          expires_at: 1.hour.from_now
        )

        PaymentRequestExpirationJob.perform_now

        assert_equal "pending", request.reload.status
      end

      test "does not expire requests without expires_at" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "pending",
          expires_at: nil
        )

        PaymentRequestExpirationJob.perform_now

        assert_equal "pending", request.reload.status
      end

      test "does not expire already approved requests" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "approved",
          expires_at: 1.hour.ago
        )

        PaymentRequestExpirationJob.perform_now

        assert_equal "approved", request.reload.status
      end

      test "does not expire already rejected requests" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "rejected",
          expires_at: 1.hour.ago
        )

        PaymentRequestExpirationJob.perform_now

        assert_equal "rejected", request.reload.status
      end

      test "does not expire already expired requests (idempotent)" do
        request = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "expired",
          expires_at: 1.hour.ago
        )

        PaymentRequestExpirationJob.perform_now

        assert_equal "expired", request.reload.status
      end

      test "fires after_payment_request_changed callback for each expired request" do
        fired_ids = []
        RSB::Entitlements.configure do |config|
          config.after_payment_request_changed = ->(req) { fired_ids << req.id }
        end

        req1 = create_test_payment_request(
          requestable: @org, plan: @plan,
          status: "pending", expires_at: 1.hour.ago
        )
        req2 = create_test_payment_request(
          requestable: @org, plan: create_test_plan(slug: "plan-exp-2"),
          status: "processing", expires_at: 2.hours.ago
        )

        PaymentRequestExpirationJob.perform_now

        assert_includes fired_ids, req1.id
        assert_includes fired_ids, req2.id
      end
    end
  end
end
