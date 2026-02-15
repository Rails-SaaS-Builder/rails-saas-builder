# rsb-entitlements-stripe

Stripe payment provider for RSB Entitlements. Integrates Stripe Checkout Sessions for subscription and one-time payments, with webhook-driven entitlement lifecycle management. Handles subscription renewals, payment failures, and refunds automatically.

## Installation

### As part of Rails SaaS Builder

```ruby
gem "rails-saas-builder"
```

This gem is included when you add `gem "rails-saas-builder"` and enable the Stripe provider.

### Standalone

```ruby
gem "rsb-entitlements-stripe"
```

Then run:

```bash
bundle install
rails db:migrate
```

## Key Features

- Stripe Checkout Session integration (subscriptions and one-time payments)
- Webhook event handling (checkout, invoicing, subscriptions, refunds)
- Automatic entitlement activation on successful payment
- Subscription lifecycle management (renewals, cancellations, failures)
- Refund support with automatic entitlement revocation
- Customer ID persistence for returning customers
- Configurable success/cancel redirect URLs

## Basic Usage

```ruby
# Plans need a stripe_price_id in metadata
plan = RSB::Entitlements::Plan.create!(
  name: "Pro Monthly",
  interval: :monthly,
  price_cents: 2999,
  currency: "usd",
  features: { advanced_analytics: true },
  metadata: { "stripe_price_id" => "price_xxx" }
)

# Initiate a payment
result = org.request_payment(plan: plan, provider: :stripe)
redirect_to result.redirect_url  # Stripe Checkout
```

## Configuration

```ruby
# Via admin settings panel or initializer:
RSB::Settings.set("entitlements.providers.stripe.enabled", true)
RSB::Settings.set("entitlements.providers.stripe.secret_key", "sk_live_...")
RSB::Settings.set("entitlements.providers.stripe.publishable_key", "pk_live_...")
RSB::Settings.set("entitlements.providers.stripe.webhook_secret", "whsec_...")
RSB::Settings.set("entitlements.providers.stripe.success_url", "/billing/success")
RSB::Settings.set("entitlements.providers.stripe.cancel_url", "/billing/cancel")
```

## Webhook Setup

Configure your Stripe webhook endpoint to point to `/entitlements/stripe/webhooks`.

Required events:
- `checkout.session.completed`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `charge.refunded`

## Documentation

Part of [Rails SaaS Builder](../README.md). See the main README for the full picture.

## License

[LGPL-3.0](../LICENSE)
