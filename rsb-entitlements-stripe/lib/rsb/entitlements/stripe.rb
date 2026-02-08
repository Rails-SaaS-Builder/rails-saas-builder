require "stripe"
require "rsb/entitlements"
require "rsb/entitlements/stripe/version"
require "rsb/entitlements/stripe/engine"
require "rsb/entitlements/stripe/configuration"

module RSB
  module Entitlements
    module Stripe
      LOG_TAG = "[RSB::Entitlements::Stripe]"

      class << self
        def client
          @client ||= ::Stripe::StripeClient.new(
            RSB::Settings.get("entitlements.providers.stripe.secret_key")
          )
        end

        def configuration
          @configuration ||= Configuration.new
        end

        def reset!
          @client = nil
          @configuration = Configuration.new
        end
      end
    end
  end
end

require "rsb/entitlements/stripe/payment_provider"
require "rsb/entitlements/stripe/webhook_middleware"
require "rsb/entitlements/stripe/webhook_handlers"
require "rsb/entitlements/stripe/test_helper"
