# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.headers = { 'Cache-Control' => 'public, max-age=3600' }

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :memory_store
  config.action_dispatch.show_exceptions = :rescuing

  config.action_controller.allow_forgery_protection = false
  config.action_controller.perform_caching = false

  # Active Record encryption for rsb-settings
  config.active_record.encryption.primary_key = 'test-primary-key-for-rsb-admin'
  config.active_record.encryption.deterministic_key = 'test-deterministic-key-for-rsb'
  config.active_record.encryption.key_derivation_salt = 'test-key-derivation-salt-for-rsb'

  # ActionMailer configuration for email verification tests
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
end
