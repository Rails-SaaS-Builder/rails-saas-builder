# frozen_string_literal: true

module RSB
  module Auth
    # Provides backward compatibility between the old `auth.login_identifier`
    # setting and the new per-credential `auth.credentials.<key>.enabled` settings.
    #
    # When per-credential settings are NOT explicitly set in the database,
    # this bridge reads `auth.login_identifier` and infers which types should
    # be enabled. When per-credential settings ARE explicitly set, this bridge
    # is bypassed entirely — the explicit settings win.
    #
    # @see SRS-004 US-006 (Deprecate login_identifier)
    class CredentialDeprecationBridge
      IDENTIFIER_MAP = {
        'email' => { email_password: true, phone_password: false, username_password: false },
        'phone' => { email_password: false, phone_password: true, username_password: false },
        'username' => { email_password: false, phone_password: false, username_password: true }
      }.freeze

      class << self
        # Returns the enabled/disabled map for a given login_identifier value.
        #
        # @param identifier [String] "email", "phone", or "username"
        # @return [Hash<Symbol, Boolean>]
        def enabled_map_for(identifier)
          IDENTIFIER_MAP.fetch(identifier.to_s, IDENTIFIER_MAP['email'])
        end

        # Checks whether any per-credential enabled setting has been explicitly
        # set in the database (not just relying on the default).
        #
        # @return [Boolean]
        def per_credential_settings_explicit?
          RSB::Auth.credentials.all.any? do |defn|
            RSB::Settings::Setting.exists?(
              category: 'auth',
              key: "credentials.#{defn.key}.enabled"
            )
          end
        rescue StandardError
          false
        end

        # Resolves the deprecated login_identifier into per-credential settings.
        # Only called when per-credential settings are NOT explicitly set.
        # Logs a deprecation warning.
        #
        # @return [void]
        def resolve_from_login_identifier
          identifier = RSB::Settings.get('auth.login_identifier')
          fire_deprecation(
            'auth.login_identifier is deprecated. Use auth.credentials.<key>.enabled settings instead. ' \
            "Current value '#{identifier}' maps to: #{enabled_map_for(identifier).inspect}"
          )
        end

        # Register a deprecation handler (for testing).
        # @param block [Proc]
        def on_deprecation(&block)
          @deprecation_handler = block
        end

        # Clear the deprecation handler (for test teardown).
        def clear_deprecation_handler
          @deprecation_handler = nil
        end

        private

        def fire_deprecation(message)
          if @deprecation_handler
            @deprecation_handler.call(message)
          elsif defined?(Rails) && Rails.logger
            Rails.logger.warn("[RSB::Auth DEPRECATION] #{message}")
          end
        end
      end
    end
  end
end
