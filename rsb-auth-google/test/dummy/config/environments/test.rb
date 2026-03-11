# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV['CI'].present?
  config.public_file_server.headers = { 'cache-control' => 'public, max-age=3600' }
  config.consider_all_requests_local = true
  config.cache_store = :memory_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true

  # ActiveRecord encryption for rsb-settings
  config.active_record.encryption.primary_key = 'test-primary-key-for-rsb-settings'
  config.active_record.encryption.deterministic_key = 'test-deterministic-key-for-rsb'
  config.active_record.encryption.key_derivation_salt = 'test-key-derivation-salt-rsb'
end
