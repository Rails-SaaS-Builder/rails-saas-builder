# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)
require 'rsb/settings'

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Include engine migrations for testing
    config.paths['db/migrate'] << File.expand_path('../../../db/migrate', __dir__)
  end
end
