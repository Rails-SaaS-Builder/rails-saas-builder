# rsb-entitlements

`rsb-entitlements` is a minimal canonical schema for SaaS entitlements on Rails. It provides six tables that cleanly separate feature catalog, plan composition, subscription state, metered usage, and webhook idempotency — without bundling any payment logic. Payment providers (Stripe, App Store, RevenueCat) talk to this gem through two stable entry points: `Subscriptions.sync!` and `Webhooks.process`.

> **v1.0.0 (Released).** v0 → v1 is a breaking change; see [MIGRATION-v1.md](./MIGRATION-v1.md).

## Install

```ruby
gem 'rsb-entitlements'
```

```bash
bundle install
bundle exec rails db:migrate
```

## The six tables

`features` — typed feature catalog (`flag` / `metered` / `gauge`); supports soft-archive.
`plans` — named plan catalog with display ordering; soft-archive only.
`plan_features` — plan × feature composition; carries `enabled`, `limit_value`, and `period`.
`subscriptions` — provider-keyed UPSERT target; DB-enforced single active subscription per subject.
`usage_counters` — current consumed/released state per subject × feature × period.
`provider_events` — webhook idempotency envelope; unique on `(provider, event_id)`.

See [TDD-019](../../docs/tdd/019-rsb-entitlements-v1-redesign.md) §3 for column-level detail.

## Minimal example

```ruby
# 1. Declare features and plans (deploy-safe register-if-missing).
RSB::Entitlements::Feature.find_or_create_by!(key: 'sso',       kind: 'flag')
RSB::Entitlements::Feature.find_or_create_by!(key: 'api_calls', kind: 'metered', unit: 'count')

RSB::Entitlements::Plan.find_or_create_by!(key: 'pro') { |p| p.name = 'Pro' }

RSB::Entitlements::PlanFeature.find_or_create_by!(plan_key: 'pro', feature_key: 'sso') do |pf|
  pf.enabled = true
end
RSB::Entitlements::PlanFeature.find_or_create_by!(plan_key: 'pro', feature_key: 'api_calls') do |pf|
  pf.assign_attributes(limit_value: 5000, period: 'month')
end

# 2. Mix the Subject concern into your subject model.
class Workspace < ApplicationRecord
  include RSB::Entitlements::Subject
end

# 3. Upsert a subscription (from a webhook handler or a manual admin path).
RSB::Entitlements::Subscriptions.sync!(
  provider: 'stripe', provider_subscription_id: 'sub_abc',
  subject: workspace, plan_key: 'pro', status: 'active',
  current_period_start: Time.current, current_period_end: 1.month.from_now
)

# 4. Gate features at runtime.
workspace.entitled_to?(:sso)              # => true / false
workspace.consume!(:api_calls, amount: 1) # => UsageCounter or raises OverLimit
workspace.remaining_for(:api_calls)       # => Integer | nil (unlimited) | 0
```

## Webhook idempotency

```ruby
RSB::Entitlements::Webhooks.process(
  provider: 'stripe', event_id: event.id, type: event.type, payload: payload
) do
  # This block runs exactly once per (provider, event_id) pair.
  handle(event)
end
```

## Hooks

```ruby
RSB::Entitlements.on(:overage_blocked) do |subject, feature_key, attempted_amount|
  Rails.logger.warn "#{subject} hit limit on #{feature_key}"
end
```

Available events:

- `:plan_changed(subscription, from_plan_key, to_plan_key)`
- `:overage_blocked(subject, feature_key, attempted_amount)`
- `:release_blocked(subject, feature_key, attempted_amount)`
- `:period_rolled(subject, feature_key, new_period_start)`
- `:subscription_expired(subscription, prior_status)` — fires on any
  `(active|trialing) → expired` transition, regardless of whether the
  trigger was a provider webhook, an admin action, or `expire_overdue!`.
- `:feature_archived(feature_key)`
- `:plan_archived(plan_key)`

## Auto-expiration for manual subscriptions

Subscriptions whose state is owned by an external provider (Stripe, Apple, RevenueCat) are closed by their own webhook events — the gem does not auto-expire them. For `provider: 'manual'` subscriptions there is no upstream event source, so the gem provides a class method that hosts schedule themselves:

```ruby
# Sweep overdue manual subs to status='expired'. Returns the affected rows.
RSB::Entitlements::Subscriptions.expire_overdue!
```

The default `providers:` scope is `%w[manual]` for safety. Pass other providers explicitly only if you understand why you want the gem (rather than the provider's webhook) to flip the status.

Schedule it at whatever cadence fits your business — the canonical pattern is hourly, but for monthly subs daily is fine. Examples:

```ruby
# config/schedule.rb (whenever)
every 1.hour do
  runner 'RSB::Entitlements::Subscriptions.expire_overdue!'
end

# Sidekiq + sidekiq-cron
class ExpireOverdueSubscriptionsJob
  include Sidekiq::Job
  def perform = RSB::Entitlements::Subscriptions.expire_overdue!
end

# k8s CronJob: schedule a `bin/rails runner '...'` container hourly.
```

Each expired row fires `:subscription_expired(subscription, prior_status)` so you can downgrade CRM tags, send dunning emails, etc.

## Payment providers (Stripe / Apple / RevenueCat)

Adapters are plain Ruby: catch the provider webhook, verify the signature, then call `Subscriptions.sync!` (for subscription state changes) and `Webhooks.process` (for idempotency). No Stripe gem dependency is required by this core gem.

The companion gem `rsb-entitlements-stripe` is shelved at its v0 surface and is no longer wired into the umbrella build. Its CI is disabled and its source is preserved on disk; a v1 rewrite (a thin webhook bridge for `Subscriptions.sync!` / `Webhooks.process`) is deferred to a future SRS.

> **There is no rollback path. Back up before upgrading.**

## License

[LGPL-3.0](../LICENSE)
