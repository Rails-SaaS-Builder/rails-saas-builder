module RSB
  module Auth
    class CredentialRegistry
      attr_reader :definitions

      def initialize
        @definitions = {}
      end

      def register(definition)
        if definition.is_a?(CredentialDefinition)
          @definitions[definition.key] = definition
        else
          raise ArgumentError, "Expected CredentialDefinition, got #{definition.class}"
        end
      end

      def find(key)
        @definitions[key.to_sym]
      end

      def all
        @definitions.values
      end

      def authenticatable
        @definitions.values.select(&:authenticatable)
      end

      def registerable
        @definitions.values.select(&:registerable)
      end

      def for_identifier(identifier_type)
        # Find the default credential type for a given login identifier
        key = :"#{identifier_type}_password"
        @definitions[key]
      end

      def keys
        @definitions.keys
      end

      # Returns only credential definitions that are currently enabled via settings.
      # A credential type is enabled if `auth.credentials.<key>.enabled` resolves to `true`.
      # If no setting exists for the credential type, it defaults to enabled (true).
      #
      # @return [Array<CredentialDefinition>]
      def enabled
        @definitions.values.select { |defn| credential_enabled?(defn.key) }
      end

      # Returns keys of enabled credential types.
      #
      # @return [Array<Symbol>]
      def enabled_keys
        enabled.map(&:key)
      end

      # Checks if a specific credential type is enabled.
      # Returns false if the credential type is not registered.
      #
      # @param key [Symbol, String] credential type key
      # @return [Boolean]
      def enabled?(key)
        defn = @definitions[key.to_sym]
        return false unless defn

        credential_enabled?(defn.key)
      end

      private

      # Reads the enabled setting for a credential type.
      # Falls back to true if no setting is registered (backward compat / custom types
      # that haven't registered their enabled setting yet).
      #
      # @param key [Symbol] credential type key
      # @return [Boolean]
      def credential_enabled?(key)
        setting_key = "auth.credentials.#{key}.enabled"
        value = begin
          RSB::Settings.get(setting_key)
        rescue StandardError
          nil
        end
        # If no setting registered, default to true (backward compat)
        return true if value.nil?

        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
