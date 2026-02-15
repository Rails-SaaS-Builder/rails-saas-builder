# frozen_string_literal: true

module RSB
  module Entitlements
    class SettingsSchema
      def self.build
        RSB::Settings::Schema.new('entitlements') do
          setting :default_currency,
                  type: :string,
                  default: 'usd',
                  group: 'General',
                  description: 'Default currency code'

          setting :trial_days,
                  type: :integer,
                  default: 14,
                  group: 'General',
                  description: 'Default trial period in days'

          setting :grace_period_days,
                  type: :integer,
                  default: 3,
                  group: 'General',
                  description: 'Grace period after entitlement expiry (days)'

          setting :auto_create_counters,
                  type: :boolean,
                  default: true,
                  group: 'General',
                  description: 'Auto-create usage counters when entitlement is granted'

          setting :on_plan_change_usage,
                  type: :string,
                  default: 'continue',
                  group: 'General',
                  description: "Behavior on plan change: 'continue' (carry over usage) or 'reset' (fresh counter)"

          setting :payment_request_expiry_hours,
                  type: :integer,
                  default: 72,
                  group: 'General',
                  description: 'Default expiry for payment requests (hours)'
        end
      end
    end
  end
end
