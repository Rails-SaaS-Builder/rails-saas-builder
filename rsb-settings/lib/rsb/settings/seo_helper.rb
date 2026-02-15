# frozen_string_literal: true

module RSB
  module Settings
    module SeoHelper
      def rsb_seo_title
        page_title = @rsb_page_title.to_s
        app_name = RSB::Settings.get('seo.app_name').to_s

        title = if app_name.present? && page_title.present?
                  format_str = RSB::Settings.get('seo.title_format').to_s
                  format_str.gsub('%<page_title>s', page_title).gsub('%<app_name>s', app_name)
                elsif app_name.present?
                  app_name
                else
                  page_title
                end

        "<title>#{ERB::Util.html_escape(title)}</title>".html_safe
      end

      def rsb_seo_meta_tags
        tags = []
        tags << rsb_seo_title

        is_admin = (@rsb_seo_context == :admin)

        # Meta description (auth only)
        unless is_admin
          description = @rsb_meta_description.to_s
          tags << %(<meta name="description" content="#{ERB::Util.html_escape(description)}" />) if description.present?
        end

        # Robots
        if is_admin
          tags << '<meta name="robots" content="noindex, nofollow" />'
        elsif RSB::Settings.get('seo.auth_indexable') == false
          tags << '<meta name="robots" content="noindex, nofollow" />'
        end

        # Open Graph (auth only)
        unless is_admin
          page_title = @rsb_page_title.to_s
          tags << %(<meta property="og:title" content="#{ERB::Util.html_escape(page_title)}" />) if page_title.present?

          description = @rsb_meta_description.to_s
          if description.present?
            tags << %(<meta property="og:description" content="#{ERB::Util.html_escape(description)}" />)
          end

          tags << '<meta property="og:type" content="website" />'

          if respond_to?(:request) && request.present?
            canonical = canonical_url
            tags << %(<meta property="og:url" content="#{ERB::Util.html_escape(canonical)}" />)
            tags << %(<link rel="canonical" href="#{ERB::Util.html_escape(canonical)}" />)
          end

          og_image = RSB::Settings.get('seo.og_image_url').to_s
          tags << %(<meta property="og:image" content="#{ERB::Util.html_escape(og_image)}" />) if og_image.present?
        end

        tags.join("\n").html_safe
      end

      def rsb_seo_head_tags
        value = RSB::Settings.get('seo.head_tags').to_s
        value.present? ? value.html_safe : ''
      end

      def rsb_seo_body_tags
        value = RSB::Settings.get('seo.body_tags').to_s
        value.present? ? value.html_safe : ''
      end

      private

      def canonical_url
        uri = URI.parse(request.original_url)
        "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless [80, 443].include?(uri.port)}#{uri.path}"
      end
    end
  end
end
