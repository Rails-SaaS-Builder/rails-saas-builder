# frozen_string_literal: true

module RSB
  module Settings
    class SeoSettingsSchema
      # Build the SEO settings schema for the "seo" category.
      #
      # @return [RSB::Settings::Schema]
      def self.build
        RSB::Settings::Schema.new('seo') do
          setting :app_name,
                  type: :string,
                  default: '',
                  group: 'General',
                  description: 'App name used in page title suffix (empty = no suffix)'

          setting :title_format,
                  type: :string,
                  default: '%<page_title>s | %<app_name>s',
                  group: 'General',
                  description: 'Format pattern for <title> tag (use %<page_title>s and %<app_name>s placeholders)'

          setting :og_image_url,
                  type: :string,
                  default: '',
                  group: 'Open Graph',
                  description: 'Default Open Graph image URL for social sharing'

          setting :auth_indexable,
                  type: :boolean,
                  default: true,
                  group: 'Robots',
                  description: 'Allow search engines to index auth pages (login, register, etc.)'

          setting :head_tags,
                  type: :string,
                  default: '',
                  group: 'Script Injection',
                  description: 'HTML to inject in <head> on all RSB pages (analytics, fonts, etc.)'

          setting :body_tags,
                  type: :string,
                  default: '',
                  group: 'Script Injection',
                  description: 'HTML to inject before </body> on all RSB pages'
        end
      end
    end
  end
end
