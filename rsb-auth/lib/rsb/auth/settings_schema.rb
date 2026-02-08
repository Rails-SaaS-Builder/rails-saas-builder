module RSB
  module Auth
    class SettingsSchema
      def self.build
        RSB::Settings::Schema.new("auth") do
          setting :registration_mode,
                  type: :string,
                  default: "open",
                  enum: %w[open invite_only disabled],
                  group: "Registration",
                  description: "Registration mode: open, invite_only, disabled"

          setting :login_identifier,
                  type: :string,
                  default: "email",
                  enum: %w[email phone username],
                  group: "Registration",
                  description: "Primary identifier for login"

          setting :password_min_length,
                  type: :integer,
                  default: 8,
                  group: "Registration",
                  description: "Minimum password length"

          setting :session_duration,
                  type: :integer,
                  default: 86_400,
                  group: "Session & Security",
                  description: "Session duration in seconds"

          setting :max_sessions,
                  type: :integer,
                  default: 5,
                  group: "Session & Security",
                  description: "Maximum concurrent sessions per identity"

          setting :lockout_threshold,
                  type: :integer,
                  default: 5,
                  group: "Session & Security",
                  description: "Failed login attempts before lockout"

          setting :lockout_duration,
                  type: :integer,
                  default: 900,
                  group: "Session & Security",
                  description: "Lockout duration in seconds"

          setting :verification_required,
                  type: :boolean,
                  default: true,
                  group: "Registration",
                  description: "Require email/phone verification"

          setting :account_enabled,
                  type: :boolean,
                  default: true,
                  group: "Features",
                  description: "Enable account management page"

          setting :account_deletion_enabled,
                  type: :boolean,
                  default: true,
                  group: "Features",
                  depends_on: "auth.account_enabled",
                  description: "Enable self-service account deletion"
        end
      end
    end
  end
end
