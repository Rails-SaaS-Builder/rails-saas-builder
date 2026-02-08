module RSB
  module Auth
    module RateLimitable
      extend ActiveSupport::Concern

      private

      def throttle!(key:, limit: 10, period: 60)
        cache_key = "rsb_throttle:#{key}:#{request.remote_ip}"
        count = Rails.cache.increment(cache_key, 1, expires_in: period.seconds, initial: 0)

        if count > limit
          render plain: "Too many requests. Try again later.", status: :too_many_requests
        end
      end
    end
  end
end
