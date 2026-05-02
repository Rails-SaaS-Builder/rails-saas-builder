# frozen_string_literal: true

module RSB
  module Entitlements
    # v1 has no entitlements-level settings. Provider settings (e.g. Stripe
    # API keys) live in their respective billing-provider gems. Plan / pricing
    # data is application-defined via the custom plan resolver registered
    # through RSB::Entitlements.plans.
    class SettingsSchema
      def self.build
        RSB::Settings::Schema.new('entitlements') do
          # intentionally empty
        end
      end
    end
  end
end
