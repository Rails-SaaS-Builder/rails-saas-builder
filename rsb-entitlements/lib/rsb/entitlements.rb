# frozen_string_literal: true

require 'rsb/settings'
require 'rsb/entitlements/version'
require 'rsb/entitlements/engine'
require 'rsb/entitlements/configuration'
require 'rsb/entitlements/provider_definition'
require 'rsb/entitlements/provider_registry'
require 'rsb/entitlements/payment_provider/base'
require 'rsb/entitlements/payment_provider/wire'
require 'rsb/entitlements/settings_schema'
require 'rsb/entitlements/period_key_calculator'

module RSB
  module Entitlements
    class << self
      def providers
        @providers ||= ProviderRegistry.new
      end

      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def settings_schema
        @settings_schema ||= SettingsSchema.build
      end

      def reset!
        @providers = ProviderRegistry.new
        @configuration = Configuration.new
      end
    end
  end
end
