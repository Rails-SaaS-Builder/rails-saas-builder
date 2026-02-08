# rsb-settings

Foundation gem for Rails SaaS Builder. Provides a dynamic settings system with a schema registry that other gems register with. Settings resolve through a priority chain: database overrides → initializer configuration → environment variables → schema defaults. Includes locale management middleware and SEO helper utilities.

## Installation

### As part of Rails SaaS Builder

```ruby
gem "rails-saas-builder"
```

### Standalone

```ruby
gem "rsb-settings"
```

Then run:

```bash
bundle install
rails generate rsb_settings:install
rails db:migrate
```

## Key Features

- Schema-based setting definitions with type validation (string, integer, boolean, float, array, duration)
- Priority resolution chain: DB → initializer → ENV (`RSB_CATEGORY_KEY`) → default
- ActiveRecord encryption for sensitive settings
- Initializer-level locks to prevent runtime changes
- Change callbacks for reactive updates
- Grouped settings display for admin UI
- Locale middleware with cookie/Accept-Language negotiation

## Basic Usage

```ruby
# Define a settings schema
RSB::Settings.registry.define("billing") do
  setting :currency, type: :string, default: "usd"
  setting :trial_days, type: :integer, default: 14
end

# Read settings
RSB::Settings.get("billing.currency")     #=> "usd"
RSB::Settings.for("billing")              #=> { currency: "usd", trial_days: 14 }

# Write settings (persists to database)
RSB::Settings.set("billing.currency", "eur")
```

## Configuration

```ruby
RSB::Settings.configure do |config|
  config.set("billing.currency", "eur")    # initializer override
  config.lock("billing.currency")           # prevent runtime changes
  config.available_locales = %w[en de fr]
  config.default_locale = "en"
end
```

## Documentation

Part of [Rails SaaS Builder](../README.md). See the main README for the full picture.

## License

[LGPL-3.0](../LICENSE)
