# frozen_string_literal: true

require 'test_helper'

class StripeMiddlewareTest < ActiveSupport::TestCase
  test 'WebhookMiddleware is in the Rails middleware stack' do
    middlewares = Rails.application.middleware.map(&:name)
    assert_includes middlewares, 'RSB::Entitlements::Stripe::WebhookMiddleware'
  end

  test 'WebhookMiddleware path constant is set' do
    assert_equal '/rsb/stripe/webhooks',
                 RSB::Entitlements::Stripe::WebhookMiddleware::WEBHOOK_PATH
  end
end
