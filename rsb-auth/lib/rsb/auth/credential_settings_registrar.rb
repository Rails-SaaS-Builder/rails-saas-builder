# frozen_string_literal: true

module RSB
  module Auth
    # Handles registration of per-credential-type enabled settings
    # and validation callbacks (e.g., preventing disabling the last type).
    #
    # Called from the engine initializer after credential types are registered.
    class CredentialSettingsRegistrar
      # Auto-registers `auth.credentials.<key>.enabled` settings for all
      # currently registered credential types.
      #
      # @return [void]
      def self.register_enabled_settings
        definitions = RSB::Auth.credentials.all
        return if definitions.empty?

        schema = RSB::Settings::Schema.new('auth') do
          definitions.each do |defn|
            setting :"credentials.#{defn.key}.enabled",
                    type: :boolean,
                    default: true,
                    group: 'Credential Types',
                    label: defn.label,
                    description: "Enable or disable #{defn.label} as a sign-in method"

            setting :"credentials.#{defn.key}.verification_required",
                    type: :boolean,
                    default: true,
                    group: 'Credential Types',
                    label: "#{defn.label} — Verification Required",
                    depends_on: "auth.credentials.#{defn.key}.enabled",
                    description: "Require email verification before login for #{defn.label}"

            setting :"credentials.#{defn.key}.auto_verify_on_signup",
                    type: :boolean,
                    default: false,
                    group: 'Credential Types',
                    label: "#{defn.label} — Auto-verify on Signup",
                    depends_on: "auth.credentials.#{defn.key}.enabled",
                    description: "Auto-verify credentials at registration time for #{defn.label}"

            setting :"credentials.#{defn.key}.allow_login_unverified",
                    type: :boolean,
                    default: false,
                    group: 'Credential Types',
                    label: "#{defn.label} — Allow Login Unverified",
                    depends_on: "auth.credentials.#{defn.key}.enabled",
                    description: "Allow login without verification for #{defn.label}"

            setting :"credentials.#{defn.key}.registerable",
                    type: :boolean,
                    default: true,
                    group: 'Credential Types',
                    label: "#{defn.label} — Self-registration",
                    depends_on: "auth.credentials.#{defn.key}.enabled",
                    description: "Allow self-registration for #{defn.label}"
          end
        end

        RSB::Settings.registry.register(schema)
      end

      # Registers on_change callbacks that prevent disabling the last
      # enabled credential type. For each credential type, when its
      # enabled setting changes to false, check that at least one other
      # type remains enabled.
      #
      # @return [void]
      def self.register_last_type_validation
        RSB::Auth.credentials.all.each do |defn|
          setting_key = "auth.credentials.#{defn.key}.enabled"
          RSB::Settings.registry.on_change(setting_key) do |_old_value, new_value|
            # Only check when disabling (new_value is falsy)
            is_disabling = !ActiveModel::Type::Boolean.new.cast(new_value)
            if is_disabling
              # Count how many OTHER types are still enabled
              other_enabled = RSB::Auth.credentials.all.count do |other|
                next false if other.key == defn.key

                RSB::Auth.credentials.enabled?(other.key)
              end

              if other_enabled.zero?
                raise RSB::Settings::ValidationError,
                      "Cannot disable #{defn.label}: at least one credential type must remain enabled."
              end
            end
          end

          # Mutual exclusion: auto_verify_on_signup and verification_required cannot both be true
          auto_verify_key = "auth.credentials.#{defn.key}.auto_verify_on_signup"
          verification_key = "auth.credentials.#{defn.key}.verification_required"

          RSB::Settings.registry.on_change(auto_verify_key) do |_old_value, new_value|
            if ActiveModel::Type::Boolean.new.cast(new_value)
              verif = RSB::Settings.get(verification_key)
              if ActiveModel::Type::Boolean.new.cast(verif)
                raise RSB::Settings::ValidationError,
                      "Cannot enable auto-verify when verification is required for #{defn.label}. Disable verification_required first."
              end
            end
          end

          RSB::Settings.registry.on_change(verification_key) do |_old_value, new_value|
            if ActiveModel::Type::Boolean.new.cast(new_value)
              auto = RSB::Settings.get(auto_verify_key)
              if ActiveModel::Type::Boolean.new.cast(auto)
                raise RSB::Settings::ValidationError,
                      "Cannot enable verification_required when auto-verify is enabled for #{defn.label}. Disable auto_verify_on_signup first."
              end
            end
          end
        end
      end
    end
  end
end
