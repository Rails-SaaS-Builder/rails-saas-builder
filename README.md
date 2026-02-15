# Rails SaaS Builder

Full-stack SaaS framework for Rails. Modular, extensible, production-ready.

Rails SaaS Builder (RSB) is a collection of Rails engines that provide SaaS essentials out of the box. Built for Rails developers who need authentication with pluggable credentials, plan-based entitlements with usage tracking, an admin panel with role-based access control, and a dynamic settings system — all working together or independently. Use the umbrella gem for everything, or pick individual sub-gems for only what you need.

## Quick Start

Add to your Gemfile:

```ruby
gem "rails-saas-builder"
```

Then run:

```bash
bundle install
rails generate rails_saas_builder:install
rails db:migrate
rails rsb:create_admin EMAIL=admin@example.com PASSWORD=changeme
```

Visit `/admin/login` to access the admin panel.
Visit `/auth/session/new` to sign in as a user.

## Modular Architecture

RSB is composed of focused sub-gems. Use them all via `gem "rails-saas-builder"`, or pick only what you need.

### Core Gems

| Gem | Purpose |
|-----|---------|
| [rsb-settings](rsb-settings/) | Dynamic runtime settings with schema registry |
| [rsb-auth](rsb-auth/) | Identity & authentication with pluggable credentials |
| [rsb-entitlements](rsb-entitlements/) | Plans, entitlements, and usage tracking |
| [rsb-admin](rsb-admin/) | Admin panel with dynamic RBAC |

### Extension Gems

| Gem | Purpose |
|-----|---------|
| [rsb-entitlements-stripe](rsb-entitlements-stripe/) | Stripe payment provider for rsb-entitlements |

## Requirements

- Ruby >= 3.2
- Rails >= 8.0

## Development

Clone the repository and install dependencies:

```bash
git clone https://github.com/Rails-SaaS-Builder/rails-saas-builder.git
cd rsb
bundle install
```

Run the full test suite:

```bash
bundle exec rake test
```

Run a single gem's tests:

```bash
bundle exec rake test_gem GEM=rsb-auth
```

Run the linter:

```bash
bundle exec rubocop
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and how to submit pull requests.

## Security

To report a security vulnerability, please see [SECURITY.md](SECURITY.md). Do not open public issues for security concerns.

## License

Rails SaaS Builder is licensed under the [GNU Lesser General Public License v3.0](LICENSE).
