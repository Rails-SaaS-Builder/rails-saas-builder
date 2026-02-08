Rails.application.configure do
  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  config.action_controller.perform_caching = false
  config.cache_store = :memory_store

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Action Mailer config
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
end
