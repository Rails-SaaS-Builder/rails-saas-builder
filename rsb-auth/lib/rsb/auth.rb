# frozen_string_literal: true

require 'rsb/settings'
require 'rsb/auth/version'
require 'rsb/auth/engine'
require 'rsb/auth/configuration'
require 'rsb/auth/lifecycle_handler'
require 'rsb/auth/credential_conflict_error'
require 'rsb/auth/credential_definition'
require 'rsb/auth/credential_registry'
require 'rsb/auth/notifier_registry'
require 'rsb/auth/invitation_notifier/base'
require 'rsb/auth/invitation_notifier/email'
require 'rsb/auth/credential_settings_registrar'
require 'rsb/auth/credential_deprecation_bridge'
require 'rsb/auth/settings_schema'

module RSB
  module Auth
    class << self
      # Returns the credential registry singleton.
      # @return [CredentialRegistry]
      def credentials
        @credentials ||= CredentialRegistry.new
      end

      # Returns the invitation notifier registry singleton.
      # @return [NotifierRegistry]
      def notifiers
        @notifiers ||= NotifierRegistry.new
      end

      # Yields the configuration for block-style setup.
      # @yield [Configuration] the configuration instance
      def configure
        yield(configuration)
      end

      # Returns the configuration singleton.
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Returns the settings schema for registration with RSB::Settings.
      # @return [RSB::Settings::Schema]
      def settings_schema
        @settings_schema ||= SettingsSchema.build
      end

      # Resets all registries and configuration. Used in tests.
      # @return [void]
      def reset!
        @credentials = CredentialRegistry.new
        @notifiers = NotifierRegistry.new
        @configuration = Configuration.new
        @settings_schema = nil
      end
    end
  end
end
