# Contributing to Rails SaaS Builder

Thank you for your interest in contributing to RSB!

## Getting Started

1. Fork the repository
2. Clone: `git clone https://github.com/YOUR_USERNAME/rsb.git && cd rsb`
3. Install: `bundle install`
4. Test: `bundle exec rake test`

## Project Structure

RSB is a monorepo with 4 core sub-gems and 1 extension gem:

| Gem | Purpose |
|-----|---------|
| `rsb-settings` | Dynamic runtime settings with schema registry |
| `rsb-auth` | Identity & authentication with pluggable credentials |
| `rsb-entitlements` | Plans, entitlements, usage tracking |
| `rsb-admin` | Admin panel with dynamic RBAC |
| `rsb-entitlements-stripe` | Stripe payment provider extension |

Each gem has its own `test/` directory. Cross-gem integration tests live in `test/`.

## Development Workflow

1. Create a feature branch from `master`
2. Write tests for your changes (Minitest)
3. Make your changes
4. Run tests: `bundle exec rake test`
5. Run linter: `bundle exec rubocop`
6. Commit with a clear message (see below)
7. Open a pull request

## Commit Messages

- Use the imperative mood: "Add feature" not "Added feature"
- Keep the subject line under 72 characters
- Reference issue numbers where applicable: "Fix login redirect (#42)"

## Code Style

- Follow existing patterns in the codebase
- Rubocop is enforced — no new offenses
- Tests use Minitest, not RSpec
- Each gem has its own test helper — use it

## Reporting Bugs

Open a [GitHub Issue](https://github.com/Rails-SaaS-Builder/rails-saas-builder/issues) with:

- Steps to reproduce
- Expected vs actual behavior
- Ruby and Rails versions
- Which RSB gem(s) are involved

## Feature Requests

Please open a [GitHub Issue](https://github.com/Rails-SaaS-Builder/rails-saas-builder/issues) to discuss your idea **before** submitting a pull request. This helps avoid duplicated effort.

## Security Issues

Do **not** open public issues for security vulnerabilities. See [SECURITY.md](SECURITY.md) for reporting instructions.

## License

By contributing, you agree that your contributions will be licensed under the [LGPL-3.0 License](LICENSE).
