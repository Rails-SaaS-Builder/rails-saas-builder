require "test_helper"

module RSB
  module Entitlements
    module PaymentProvider
      class WireTest < ActiveSupport::TestCase
        setup do
          # Register wire provider (normally done by engine, but in tests we reset)
          RSB::Entitlements.providers.register(Wire)

          @plan = create_test_plan(price_cents: 9900, currency: "usd")
          @org = Organization.create!(name: "Wire Test Org")
          @request = create_test_payment_request(
            requestable: @org,
            plan: @plan,
            provider_key: "wire",
            status: "pending"
          )
        end

        # -- Class methods --

        test "provider_key is :wire" do
          assert_equal :wire, Wire.provider_key
        end

        test "provider_label is Wire Transfer" do
          assert_equal "Wire Transfer", Wire.provider_label
        end

        test "manual_resolution? is true" do
          assert Wire.manual_resolution?
        end

        test "admin_actions are approve and reject" do
          assert_equal [:approve, :reject], Wire.admin_actions
        end

        test "refundable? is false" do
          assert_not Wire.refundable?
        end

        test "has settings_schema with bank fields" do
          assert_not_nil Wire.settings_schema
        end

        # -- initiate! --

        test "initiate! transitions status to processing" do
          provider = Wire.new(@request)
          provider.initiate!
          @request.reload
          assert_equal "processing", @request.status
        end

        test "initiate! stores bank details in provider_data" do
          with_settings(
            "entitlements.providers.wire.bank_name" => "Acme Bank",
            "entitlements.providers.wire.account_number" => "1234567890",
            "entitlements.providers.wire.routing_number" => "021000021"
          ) do
            provider = Wire.new(@request)
            provider.initiate!
            @request.reload

            assert_equal "Acme Bank", @request.provider_data["bank_name"]
            assert_equal "1234567890", @request.provider_data["account_number"]
            assert_equal "021000021", @request.provider_data["routing_number"]
          end
        end

        test "initiate! returns instructions hash" do
          with_settings("entitlements.providers.wire.bank_name" => "Acme Bank") do
            provider = Wire.new(@request)
            result = provider.initiate!

            assert result.key?(:instructions)
            assert_match(/99\.00/, result[:instructions])
            assert_match(/Acme Bank/, result[:instructions])
          end
        end

        test "initiate! sets expires_at from auto_expire_hours setting" do
          with_settings("entitlements.providers.wire.auto_expire_hours" => 48) do
            provider = Wire.new(@request)

            freeze_time do
              provider.initiate!
              @request.reload
              assert_in_delta 48.hours.from_now, @request.expires_at, 1.second
            end
          end
        end

        test "initiate! uses custom instructions template when set" do
          with_settings(
            "entitlements.providers.wire.instructions" => "Custom: send %{amount} to %{bank_name}",
            "entitlements.providers.wire.bank_name" => "Custom Bank"
          ) do
            provider = Wire.new(@request)
            result = provider.initiate!

            assert_match(/Custom:/, result[:instructions])
            assert_match(/Custom Bank/, result[:instructions])
          end
        end

        # -- complete! --

        test "complete! grants entitlement to requestable" do
          @request.update!(status: "processing")
          provider = Wire.new(@request)
          provider.complete!

          @request.reload
          assert_equal "approved", @request.status
          assert_not_nil @request.entitlement_id

          entitlement = @request.entitlement
          assert_equal "active", entitlement.status
          assert_equal @plan, entitlement.plan
          assert_equal "wire", entitlement.provider
        end

        test "complete! is a no-op if request is not actionable" do
          @request.update_columns(status: "approved")
          provider = Wire.new(@request)
          provider.complete!
          # No error, no change
          assert_equal "approved", @request.reload.status
        end

        # -- reject! --

        test "reject! transitions status to rejected" do
          @request.update!(status: "processing")
          provider = Wire.new(@request)
          provider.reject!
          @request.reload
          assert_equal "rejected", @request.status
        end

        test "reject! does not affect entitlements" do
          @request.update!(status: "processing")
          provider = Wire.new(@request)
          provider.reject!
          assert_nil @request.reload.entitlement_id
        end

        test "reject! is a no-op if request is not actionable" do
          @request.update_columns(status: "rejected")
          provider = Wire.new(@request)
          provider.reject!
          assert_equal "rejected", @request.reload.status
        end

        # -- admin_details --

        test "admin_details returns bank info from provider_data" do
          @request.update!(provider_data: {
            "bank_name" => "Acme Bank",
            "account_number" => "123",
            "routing_number" => "456",
            "instructions_sent_at" => "2026-02-12T10:00:00Z"
          })

          provider = Wire.new(@request)
          details = provider.admin_details

          assert_equal "Acme Bank", details["Bank Name"]
          assert_equal "123", details["Account Number"]
          assert_equal "456", details["Routing Number"]
          assert details.key?("Instructions Sent At")
        end
      end
    end
  end
end
