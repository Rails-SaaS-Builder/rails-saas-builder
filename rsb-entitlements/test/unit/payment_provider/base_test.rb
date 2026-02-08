require "test_helper"

module RSB
  module Entitlements
    module PaymentProvider
      class BaseTest < ActiveSupport::TestCase
        # -- Abstract class methods raise NotImplementedError --

        test "provider_key raises NotImplementedError" do
          assert_raises(NotImplementedError) { Base.provider_key }
        end

        test "provider_label raises NotImplementedError" do
          assert_raises(NotImplementedError) { Base.provider_label }
        end

        test "manual_resolution? returns false by default" do
          assert_equal false, Base.manual_resolution?
        end

        test "admin_actions returns empty array by default" do
          assert_equal [], Base.admin_actions
        end

        test "refundable? returns false by default" do
          assert_equal false, Base.refundable?
        end

        test "required_settings returns empty array by default" do
          assert_equal [], Base.required_settings
        end

        # -- Instance methods --

        test "initialize stores payment_request" do
          request = Object.new
          instance = Base.new(request)
          assert_equal request, instance.payment_request
        end

        test "initiate! raises NotImplementedError" do
          instance = Base.new(nil)
          assert_raises(NotImplementedError) { instance.initiate! }
        end

        test "complete! raises NotImplementedError" do
          instance = Base.new(nil)
          assert_raises(NotImplementedError) { instance.complete! }
        end

        test "reject! raises NotImplementedError" do
          instance = Base.new(nil)
          assert_raises(NotImplementedError) { instance.reject! }
        end

        test "refund! raises NotImplementedError" do
          instance = Base.new(nil)
          assert_raises(NotImplementedError) { instance.refund! }
        end

        test "admin_details returns empty hash by default" do
          instance = Base.new(nil)
          assert_equal({}, instance.admin_details)
        end

        # -- settings_schema class method --

        test "settings_schema stores and yields block" do
          provider_class = Class.new(Base) do
            def self.provider_key = :test_settings
            def self.provider_label = "Test Settings"

            settings_schema do
              setting :api_key, type: :string, default: ""
            end
          end

          assert_not_nil provider_class.instance_variable_get(:@settings_schema_block)
        end
      end
    end
  end
end
