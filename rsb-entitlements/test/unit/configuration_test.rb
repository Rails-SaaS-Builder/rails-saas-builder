require "test_helper"

module RSB
  module Entitlements
    class ConfigurationTest < ActiveSupport::TestCase
      test "after_payment_request_changed defaults to nil" do
        config = RSB::Entitlements::Configuration.new
        assert_nil config.after_payment_request_changed
      end

      test "after_payment_request_changed can be set to a proc" do
        config = RSB::Entitlements::Configuration.new
        callback = ->(request) { request }
        config.after_payment_request_changed = callback
        assert_equal callback, config.after_payment_request_changed
      end
    end
  end
end
