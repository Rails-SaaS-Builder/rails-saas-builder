# frozen_string_literal: true

Rails.application.configure do
  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application.
  config.eager_load = ENV['CI'].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { 'cache-control' => 'public, max-age=3600' }

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :memory_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Action Mailer config for testing
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
end
