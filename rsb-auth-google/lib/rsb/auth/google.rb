# frozen_string_literal: true

require 'jwt'
require 'rsb/auth'
require 'rsb/auth/google/version'
require 'rsb/auth/google/engine'
require 'rsb/auth/google/configuration'
require 'rsb/auth/google/settings_schema'
require 'rsb/auth/google/jwks_loader'
require 'rsb/auth/google/test_helper'

module RSB
  module Auth
    module Google
      LOG_TAG = '[RSB::Auth::Google]'

      class << self
        def configuration
          @configuration ||= Configuration.new
        end

        def configure
          yield(configuration)
        end

        def reset!
          @configuration = Configuration.new
        end
      end
    end
  end
end
