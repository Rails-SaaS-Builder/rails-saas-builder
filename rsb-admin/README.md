# rsb-admin

Lightweight, registrable admin panel for Rails SaaS Builder. Features dynamic resource CRUD, role-based access control with granular permissions, settings management, multi-theme support, and optional two-factor authentication. Other gems register resources and pages lazily via `ActiveSupport.on_load(:rsb_admin)`.

## Installation

### As part of Rails SaaS Builder

```ruby
gem "rails-saas-builder"
```

### Standalone

```ruby
gem "rsb-admin"
```

Then run:

```bash
bundle install
rails generate rsb_admin:install
rails db:migrate
```

## Key Features

- Dynamic resource registration with DSL (columns, filters, form fields)
- Role-based access control with per-resource, per-action permissions
- Settings management page (tabbed by category)
- Built-in themes: default and modern (dark/light)
- Admin user management with email verification
- Two-factor authentication (TOTP with backup codes)
- Session management and device tracking
- Breadcrumb navigation and pagination
- Test kit for extension developers
- Lazy resource registration via `on_load(:rsb_admin)` hooks

## Basic Usage

```ruby
# Register resources from another gem
ActiveSupport.on_load(:rsb_admin) do |registry|
  registry.register_category "Content" do
    resource Post, icon: "file-text", actions: [:index, :show, :edit, :update] do
      column :title, sortable: true, link: true
      column :status, formatter: :badge
      filter :status, type: :select, options: %w[draft published]
      form_field :title, type: :text, required: true
      form_field :body, type: :textarea
    end
  end
end
```

## Configuration

```ruby
RSB::Admin.configure do |config|
  config.app_name = "My SaaS Admin"
  config.company_name = "Acme Inc"
  config.theme = :modern
end
```

## Test Kit

```ruby
# In your integration tests
include RSB::Admin::TestKit::Helpers

admin = create_test_admin!(superadmin: true)
sign_in_admin(admin)
```

## Documentation

Part of [Rails SaaS Builder](../README.md). See the main README for the full picture.

## License

[LGPL-3.0](../LICENSE)
