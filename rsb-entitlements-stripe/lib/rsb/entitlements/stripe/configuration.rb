# frozen_string_literal: true

module RSB
  module Entitlements
    module Stripe
      class Configuration
        attr_accessor :skip_webhook_verification

        def initialize
          @skip_webhook_verification = false
        end
      end
    end
  end
end
