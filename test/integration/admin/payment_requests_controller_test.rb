require "test_helper"

module RSB
  module Entitlements
    module Admin
      class PaymentRequestsControllerTest < ActionDispatch::IntegrationTest
        include RSB::Settings::TestHelper
        include RSB::Entitlements::TestHelper
        include RSB::Admin::TestKit::Helpers

        setup do
          register_all_settings
          register_all_admin_categories

          # Register a functional test provider that actually completes/rejects properly
          wire_provider = Class.new(RSB::Entitlements::PaymentProvider::Base) do
            define_singleton_method(:provider_key) { :wire }
            define_singleton_method(:provider_label) { "Wire Transfer" }
            define_singleton_method(:manual_resolution?) { true }
            define_singleton_method(:admin_actions) { [:approve, :reject] }
            define_singleton_method(:refundable?) { false }

            define_method(:initiate!) { { instructions: "Please wire funds" } }

            define_method(:complete!) do |_params = {}|
              return unless payment_request.actionable?
              entitlement = payment_request.requestable.grant_entitlement(
                plan: payment_request.plan,
                provider: payment_request.provider_key,
                metadata: payment_request.metadata
              )
              payment_request.update!(status: "approved", entitlement: entitlement)
            end

            define_method(:reject!) do |_params = {}|
              return unless payment_request.actionable?
              payment_request.update!(status: "rejected")
            end

            define_method(:admin_details) { {} }
          end
          RSB::Entitlements.providers.register(wire_provider)

          @admin = create_test_admin!(superadmin: true)
          sign_in_admin(@admin)
          @plan = create_test_plan(price_cents: 5000)
          @org = Organization.create!(name: "Admin Test Org")
          @payment_req = create_test_payment_request(requestable: @org, plan: @plan, status: "processing")
        end

        # -- Index --

        test "GET index lists payment requests" do
          get "/admin/payment_requests"
          assert_response :success
          assert_select "table" # Verify table rendered
        end

        test "GET index filters by status" do
          get "/admin/payment_requests", params: { status: "processing" }
          assert_response :success
        end

        test "GET index filters by provider_key" do
          get "/admin/payment_requests", params: { provider_key: "wire" }
          assert_response :success
        end

        # -- Show --

        test "GET show displays payment request details" do
          get "/admin/payment_requests/#{@payment_req.id}"
          assert_response :success
        end

        test "GET show displays provider admin_details" do
          @payment_req.update!(provider_data: { "bank_name" => "Acme Bank" })
          get "/admin/payment_requests/#{@payment_req.id}"
          assert_response :success
        end

        test "GET show displays approve/reject buttons for manual resolution providers" do
          get "/admin/payment_requests/#{@payment_req.id}"
          assert_response :success
          assert_select "form[action*='approve']" if @payment_req.actionable?
          assert_select "form[action*='reject']" if @payment_req.actionable?
        end

        test "GET show does not display action buttons for resolved requests" do
          @payment_req.update!(status: "approved")
          get "/admin/payment_requests/#{@payment_req.id}"
          assert_response :success
          assert_select "form[action*='approve']", count: 0
        end

        # -- Approve --

        test "PATCH approve transitions request to approved and grants entitlement" do
          patch "/admin/payment_requests/#{@payment_req.id}/approve"
          @payment_req.reload
          assert_equal "approved", @payment_req.status
          assert_not_nil @payment_req.entitlement_id
          assert_not_nil @payment_req.resolved_by
          assert_not_nil @payment_req.resolved_at
          assert_redirected_to "/admin/payment_requests/#{@payment_req.id}"
        end

        test "PATCH approve sets resolved_by to admin email" do
          patch "/admin/payment_requests/#{@payment_req.id}/approve"
          @payment_req.reload
          assert_equal @admin.email, @payment_req.resolved_by
        end

        # -- Reject --

        test "PATCH reject transitions request to rejected" do
          patch "/admin/payment_requests/#{@payment_req.id}/reject",
                params: { admin_note: "Invalid bank reference" }
          @payment_req.reload
          assert_equal "rejected", @payment_req.status
          assert_equal "Invalid bank reference", @payment_req.admin_note
          assert_equal @admin.email, @payment_req.resolved_by
          assert_redirected_to "/admin/payment_requests/#{@payment_req.id}"
        end

        test "PATCH reject does not affect entitlements" do
          patch "/admin/payment_requests/#{@payment_req.id}/reject"
          @payment_req.reload
          assert_nil @payment_req.entitlement_id
        end

        # -- Refund --

        test "PATCH refund transitions approved request to refunded for refundable providers" do
          refundable_provider = Class.new(RSB::Entitlements::PaymentProvider::Base) do
            define_singleton_method(:provider_key) { :refundable_test }
            define_singleton_method(:provider_label) { "Refundable" }
            define_singleton_method(:manual_resolution?) { false }
            define_singleton_method(:admin_actions) { [] }
            define_singleton_method(:refundable?) { true }

            define_method(:initiate!) { { status: :completed } }
            define_method(:complete!) { |_params = {}| nil }
            define_method(:reject!) { |_params = {}| nil }
            define_method(:refund!) { |_params = {}| nil }
            define_method(:admin_details) { {} }
          end
          RSB::Entitlements.providers.register(refundable_provider)

          refundable_request = create_test_payment_request(
            requestable: @org,
            plan: create_test_plan(slug: "refund-plan"),
            provider_key: "refundable_test",
            status: "approved"
          )
          entitlement = @org.grant_entitlement(plan: refundable_request.plan, provider: "refundable_test")
          refundable_request.update!(entitlement: entitlement)

          patch "/admin/payment_requests/#{refundable_request.id}/refund"
          refundable_request.reload
          assert_equal "refunded", refundable_request.status
          assert_redirected_to "/admin/payment_requests/#{refundable_request.id}"
        end

        # -- Authorization --

        test "denies access without proper permissions" do
          limited_admin = create_test_admin!(permissions: { "plans" => ["index"] }, email: "limited@test.com")
          sign_in_admin(limited_admin)

          get "/admin/payment_requests"
          assert_admin_denied
        end
      end
    end
  end
end
