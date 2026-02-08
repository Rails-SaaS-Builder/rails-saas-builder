require "rack/request"

module RSB
  module Entitlements
    module Stripe
      class WebhookMiddleware
        WEBHOOK_PATH = "/rsb/stripe/webhooks"

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)

          unless request.post? && request.path_info == WEBHOOK_PATH
            return @app.call(env)
          end

          handle_webhook(env)
        end

        private

        def handle_webhook(env)
          payload = env["rack.input"].read
          env["rack.input"].rewind

          sig_header = env["HTTP_STRIPE_SIGNATURE"]

          unless sig_header.present?
            Rails.logger.warn("#{LOG_TAG} Missing webhook signature")
            return [400, { "Content-Type" => "text/plain" }, ["Missing signature"]]
          end

          event = construct_event(payload, sig_header)
          return [400, { "Content-Type" => "text/plain" }, ["Invalid signature"]] unless event

          Rails.logger.info("#{LOG_TAG} Received event: #{event.type} (#{event.id})")

          begin
            WebhookHandlers.handle(event)
          rescue => e
            Rails.logger.error("#{LOG_TAG} Error processing #{event.type}: #{e.message}")
            return [422, { "Content-Type" => "text/plain" }, ["Processing error: #{e.message}"]]
          end

          [200, { "Content-Type" => "text/plain" }, ["OK"]]
        end

        def construct_event(payload, sig_header)
          if RSB::Entitlements::Stripe.configuration.skip_webhook_verification
            data = JSON.parse(payload)
            return ::Stripe::Event.construct_from(data)
          end

          webhook_secret = RSB::Settings.get("entitlements.providers.stripe.webhook_secret")
          ::Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
        rescue ::Stripe::SignatureVerificationError => e
          Rails.logger.warn("#{LOG_TAG} Invalid webhook signature: #{e.message}")
          nil
        rescue JSON::ParserError => e
          Rails.logger.warn("#{LOG_TAG} Invalid JSON payload: #{e.message}")
          nil
        end

        LOG_TAG = RSB::Entitlements::Stripe::LOG_TAG
      end
    end
  end
end
