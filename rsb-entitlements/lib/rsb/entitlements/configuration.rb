module RSB
  module Entitlements
    class Configuration
      attr_accessor :after_entitlement_changed,
                    :after_usage_limit_reached,
                    :after_plan_changed,
                    :after_payment_request_changed

      def initialize
        @after_entitlement_changed = nil
        @after_usage_limit_reached = nil
        @after_plan_changed = nil
        @after_payment_request_changed = nil
      end
    end
  end
end
