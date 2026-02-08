# rsb-entitlements

Plan-based feature gating, entitlements, and metered usage tracking for Rails SaaS Builder. Drop-in `Entitleable` concern for any model. Extensible provider registry for payment integrations (Stripe, wire transfers, admin grants). Includes usage counter ledger and automated expiration.

## Installation

### As part of Rails SaaS Builder

```ruby
gem "rails-saas-builder"
```

### Standalone

```ruby
gem "rsb-entitlements"
```

Then run:

```bash
bundle install
rails generate rsb_entitlements:install
rails db:migrate
```

## Key Features

- Plan management with feature flags and usage limits
- `Entitleable` concern: mix into any model for plan-based access
- Feature checking: `entitled_to?(:feature_name)`
- Usage metering: `within_limit?(:metric)`, `increment_usage(:metric)`
- Pluggable payment providers (Stripe, wire transfer, custom)
- Payment request lifecycle with automatic expiration
- Usage counter ledger (daily, weekly, monthly, cumulative periods)
- Automatic entitlement expiration

## Basic Usage

```ruby
# Add to your model
class Organization < ApplicationRecord
  include RSB::Entitlements::Entitleable
end

# Check features and usage
org.entitled_to?(:advanced_analytics)  #=> true/false
org.within_limit?(:api_calls)          #=> true/false
org.increment_usage(:api_calls, 1)

# Grant an entitlement
org.grant_entitlement(plan: plan, provider: :admin)

# Request payment
org.request_payment(plan: premium_plan, provider: :stripe)
```

## Configuration

```ruby
RSB::Entitlements.configure do |config|
  config.after_entitlement_changed = ->(entitlement) { ... }
  config.after_usage_limit_reached = ->(counter) { ... }
end
```

## Documentation

Part of [Rails SaaS Builder](../README.md). See the main README for the full picture.

## License

[LGPL-3.0](../LICENSE)
