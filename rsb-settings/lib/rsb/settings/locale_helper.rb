# frozen_string_literal: true

module RSB
  module Settings
    module LocaleHelper
      def rsb_available_locales
        RSB::Settings.available_locales
      end

      def rsb_current_locale
        I18n.locale.to_s
      end

      def rsb_locale_display_name(code)
        RSB::Settings.locale_display_name(code)
      end

      def rsb_locale_switcher(current_path: nil)
        locales = RSB::Settings.available_locales
        return ''.html_safe if locales.size <= 1

        path = current_path || (respond_to?(:request) ? request.fullpath : '/')
        current = rsb_current_locale

        parts = locales.map do |loc|
          if loc == current
            %(<span class="rsb-locale-current">#{ERB::Util.html_escape(RSB::Settings.locale_display_name(loc))}</span>)
          else
            <<~HTML.strip
              <form action="/rsb/locale" method="post" style="display:inline">
                <input type="hidden" name="locale" value="#{ERB::Util.html_escape(loc)}">
                <input type="hidden" name="redirect_to" value="#{ERB::Util.html_escape(path)}">
                <button type="submit" class="rsb-locale-link">#{ERB::Util.html_escape(RSB::Settings.locale_display_name(loc))}</button>
              </form>
            HTML
          end
        end

        %(<nav class="rsb-locale-switcher">#{parts.join(' ')}</nav>).html_safe
      end
    end
  end
end
