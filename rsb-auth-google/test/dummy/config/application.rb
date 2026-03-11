# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)
require 'rsb/settings'
require 'rsb/auth'
require 'rsb-auth-google'

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.generators.system_tests = nil

    # Include rsb-settings migrations
    rsb_settings_migrations = File.expand_path('../../../../rsb-settings/db/migrate', __dir__)
    config.paths['db/migrate'] << rsb_settings_migrations

    # Include rsb-auth migrations
    rsb_auth_migrations = File.expand_path('../../../../rsb-auth/db/migrate', __dir__)
    config.paths['db/migrate'] << rsb_auth_migrations
  end
end
