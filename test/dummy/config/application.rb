# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)

# Require all RSB gems
require 'rsb/settings'
require 'rsb/auth'
require 'rsb/entitlements'
require 'rsb-entitlements-stripe'
require 'rsb/admin'

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Include migrations from all sub-gems
    config.paths['db/migrate'] << File.expand_path('../../../rsb-settings/db/migrate', __dir__)
    config.paths['db/migrate'] << File.expand_path('../../../rsb-auth/db/migrate', __dir__)
    config.paths['db/migrate'] << File.expand_path('../../../rsb-entitlements/db/migrate', __dir__)
    config.paths['db/migrate'] << File.expand_path('../../../rsb-admin/db/migrate', __dir__)

    # Add engine asset paths to Propshaft
    config.assets.paths << File.expand_path('../../../rsb-admin/app/assets/stylesheets', __dir__)
    config.assets.paths << File.expand_path('../../../rsb-admin/app/assets/javascripts', __dir__)

    # Configure I18n locales for QA testing
    config.i18n.available_locales = %i[en de fr]
    config.i18n.default_locale = :en
  end
end
