# frozen_string_literal: true

require 'rsb/settings'
require 'rsb/entitlements/version'
require 'rsb/entitlements/errors'
require 'rsb/entitlements/hook_registry'
require 'rsb/entitlements/settings_schema'
require 'rsb/entitlements/period_calculator'
require 'rsb/entitlements/resolver'
require 'rsb/entitlements/recorder'
require 'rsb/entitlements/subscriptions'
require 'rsb/entitlements/engine'
require 'rsb/entitlements/webhooks'

module RSB
  module Entitlements
    class << self
      # @return [RSB::Entitlements::HookRegistry] the process-wide hook registry
      def hooks
        @hooks ||= HookRegistry.new
      end

      # Register a subscriber for `event`. Shorthand for `hooks.on(event, &block)`.
      #
      # @param event [Symbol]
      # @yield see {HookRegistry#on}
      def on(event, &block)
        hooks.on(event, &block)
      end

      # @return [RSB::Entitlements::SettingsSchema] schema registered into rsb-settings
      def settings_schema
        @settings_schema ||= SettingsSchema.build
      end

      # Reset all in-memory module state. Called by the test helper in setup
      # and teardown. Does NOT touch the database.
      def reset!
        @hooks = HookRegistry.new
      end
    end
  end
end
