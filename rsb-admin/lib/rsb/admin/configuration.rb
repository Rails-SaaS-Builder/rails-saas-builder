# frozen_string_literal: true

module RSB
  module Admin
    # Holds configuration options for the RSB Admin panel.
    #
    # Instances are created by {RSB::Admin.configuration} and configured
    # via {RSB::Admin.configure}. Each attribute has a sensible default
    # that can be overridden in an initializer.
    #
    # @example
    #   RSB::Admin.configure do |config|
    #     config.app_name = "My App Admin"
    #     config.theme = :modern
    #     config.enabled = true
    #     config.company_name = "Acme Corp"
    #     config.logo_url = "/images/logo.svg"
    #     config.footer_text = "© 2024 Acme Corp"
    #   end
    class Configuration
      # @return [Boolean] whether the admin panel is enabled
      attr_accessor :enabled

      # @return [String] the display name shown in the admin panel header
      attr_accessor :app_name

      # @return [String] company or product name shown in footer/login
      attr_accessor :company_name

      # @return [String] URL to logo image shown in sidebar header
      attr_accessor :logo_url

      # @return [String] custom footer text
      attr_accessor :footer_text

      # @return [Integer] default number of records per page in index views
      attr_accessor :per_page

      # @return [Symbol] the active theme key (must match a registered theme)
      attr_accessor :theme

      # @return [String, nil] optional path prefix for host-app view overrides
      attr_accessor :view_overrides_path

      # @return [String] the layout template used by admin controllers
      attr_accessor :layout

      # @return [String] from address for admin emails
      attr_accessor :mailer_sender

      # @return [ActiveSupport::Duration] verification token lifetime
      attr_accessor :email_verification_expiry

      def initialize
        @enabled = true
        @app_name = 'Admin'
        @company_name = ''
        @logo_url = ''
        @footer_text = ''
        @per_page = 25
        @theme = :default
        @view_overrides_path = nil
        @layout = 'rsb/admin/application'
        @mailer_sender = 'no-reply@example.com'
        @email_verification_expiry = 24.hours
      end
    end
  end
end
