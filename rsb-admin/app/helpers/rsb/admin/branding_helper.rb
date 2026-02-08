module RSB
  module Admin
    module BrandingHelper
      # Returns the resolved app name from settings.
      #
      # @return [String] the admin panel title
      def rsb_admin_app_name
        RSB::Settings.get("admin.app_name").to_s.presence || "Admin"
      end

      # Returns the resolved logo URL from settings.
      # Empty string means "not set."
      #
      # @return [String] the logo URL or empty string
      def rsb_admin_logo_url
        RSB::Settings.get("admin.logo_url").to_s
      end

      # Returns the resolved company name from settings.
      # Empty string means "not set."
      #
      # @return [String] the company name or empty string
      def rsb_admin_company_name
        RSB::Settings.get("admin.company_name").to_s
      end

      # Returns the resolved footer text from settings.
      # Empty string means "not set."
      #
      # @return [String] the footer text or empty string
      def rsb_admin_footer_text
        RSB::Settings.get("admin.footer_text").to_s
      end
    end
  end
end
