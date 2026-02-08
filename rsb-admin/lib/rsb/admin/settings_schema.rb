module RSB
  module Admin
    class SettingsSchema
      def self.build
        RSB::Settings::Schema.new("admin") do
          setting :enabled,
                  type: :boolean,
                  default: true,
                  group: "General",
                  description: "Enable or disable the admin panel"

          setting :app_name,
                  type: :string,
                  default: "Admin",
                  group: "Branding",
                  description: "Admin panel title"

          setting :company_name,
                  type: :string,
                  default: "",
                  group: "Branding",
                  description: "Company or product name"

          setting :logo_url,
                  type: :string,
                  default: "",
                  group: "Branding",
                  description: "URL to logo image (sidebar header)"

          setting :footer_text,
                  type: :string,
                  default: "",
                  group: "Branding",
                  description: "Custom footer text"

          setting :theme,
                  type: :string,
                  default: "default",
                  enum: -> { RSB::Admin.themes.keys.map(&:to_s) },
                  group: "General",
                  description: "Admin panel theme"

          setting :per_page,
                  type: :integer,
                  default: 25,
                  group: "General",
                  description: "Default pagination size"

          setting :require_two_factor,
                  type: :boolean,
                  default: false,
                  group: "Security",
                  description: "Require all admin users to enable two-factor authentication"
        end
      end
    end
  end
end
