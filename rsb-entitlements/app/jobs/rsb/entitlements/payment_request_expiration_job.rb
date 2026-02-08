module RSB
  module Entitlements
    # Expires stale payment requests whose expires_at has passed.
    # Only affects actionable requests (pending, processing).
    # Sets resolved_by to "system:expiration" and resolved_at to current time.
    #
    # Schedule this job to run periodically (e.g., every hour via cron or recurring job).
    #
    # @example
    #   PaymentRequestExpirationJob.perform_later
    class PaymentRequestExpirationJob < ApplicationJob
      queue_as :default

      def perform
        PaymentRequest
          .actionable
          .where("expires_at <= ?", Time.current)
          .where.not(expires_at: nil)
          .find_each do |request|
            request.update!(
              status: "expired",
              resolved_by: "system:expiration",
              resolved_at: Time.current
            )
          end
      end
    end
  end
end
