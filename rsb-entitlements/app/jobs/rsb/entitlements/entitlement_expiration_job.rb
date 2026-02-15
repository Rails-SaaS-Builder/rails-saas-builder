# frozen_string_literal: true

module RSB
  module Entitlements
    class EntitlementExpirationJob < ApplicationJob
      queue_as :default

      def perform
        Entitlement.active
                   .where('expires_at <= ?', Time.current)
                   .find_each(&:expire!)
      end
    end
  end
end
