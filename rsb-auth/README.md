# rsb-auth

Identity and authentication engine for Rails SaaS Builder. Provides a flexible identity system with pluggable credential types (email+password, username+password out of the box), session management, password reset, email verification, and user invitations. Extensible via a credential registry for custom auth methods.

## Installation

### As part of Rails SaaS Builder

```ruby
gem "rails-saas-builder"
```

### Standalone

```ruby
gem "rsb-auth"
```

Then run:

```bash
bundle install
rails generate rsb_auth:install
rails db:migrate
```

## Key Features

- Pluggable credential types with auto-detection
- Session management with configurable TTL and max concurrent sessions
- Email verification with secure token flow
- Password reset with 2-hour expiry tokens
- User invitations with 7-day expiry
- Account management (profile, password change, deletion)
- Rate limiting and lockout protection
- Configurable registration modes (open, invite-only, disabled)
- Extensible identity model via `identity_concerns`
- Pre-built auth views (login, registration, password reset, account)

## Basic Usage

```ruby
# Register a credential type
RSB::Auth.credentials.register(
  RSB::Auth::CredentialDefinition.new(
    key: :email_password,
    class_name: "RSB::Auth::Credential::EmailPassword",
    authenticatable: true,
    registerable: true,
    label: "Email & Password"
  )
)

# Extend the Identity model
RSB::Auth.configure do |config|
  config.identity_concerns = [MyApp::HasProfile]
end
```

## Configuration

```ruby
RSB::Auth.configure do |config|
  config.lifecycle_handler = "MyApp::AuthHandler"
  config.identity_concerns = [MyApp::HasProfile]
  config.permitted_account_params = [:name, :avatar_url]
end
```

## Documentation

Part of [Rails SaaS Builder](../README.md). See the main README for the full picture.

## License

[LGPL-3.0](../LICENSE)
