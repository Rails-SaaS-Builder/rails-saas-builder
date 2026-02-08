require "rsb/settings"
require "rsb/auth/version"
require "rsb/auth/engine"
require "rsb/auth/configuration"
require "rsb/auth/lifecycle_handler"
require "rsb/auth/credential_conflict_error"
require "rsb/auth/credential_definition"
require "rsb/auth/credential_registry"
require "rsb/auth/credential_settings_registrar"
require "rsb/auth/credential_deprecation_bridge"
require "rsb/auth/settings_schema"

module RSB
  module Auth
    class << self
      # --- Credential Registry ---

      def credentials
        @credential_registry ||= CredentialRegistry.new
      end

      # --- Configuration (lifecycle handler) ---

      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end

      # --- Settings Schema (pure data) ---

      def settings_schema
        @settings_schema ||= SettingsSchema.build
      end

      # --- Test support ---

      def reset!
        @credential_registry = CredentialRegistry.new
        @configuration = Configuration.new
        @settings_schema = nil
      end
    end
  end
end
