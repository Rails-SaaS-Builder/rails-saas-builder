# frozen_string_literal: true

# RSB Settings configuration
# See: https://github.com/Rails-SaaS-Builder/rails-saas-builder

RSB::Settings.configure do |config|
  # Lock settings so they're visible in admin but not editable:
  # config.lock "auth.registration_mode"
  # config.lock "entitlements.default_currency"

  # Set initializer-level overrides (takes priority over ENV and defaults):
  # config.set "auth.registration_mode", "open"
  # config.set "auth.password_min_length", 10
end
