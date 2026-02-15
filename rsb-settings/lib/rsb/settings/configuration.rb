# frozen_string_literal: true

module RSB
  module Settings
    class Configuration
      BUILT_IN_LOCALE_NAMES = {
        'en' => 'English',
        'de' => 'Deutsch',
        'fr' => 'Français',
        'es' => 'Español',
        'pt' => 'Português',
        'it' => 'Italiano',
        'nl' => 'Nederlands',
        'ja' => '日本語',
        'zh' => '中文',
        'ko' => '한국어',
        'ru' => 'Русский',
        'ar' => 'العربية',
        'pl' => 'Polski',
        'sv' => 'Svenska',
        'da' => 'Dansk',
        'nb' => 'Norsk',
        'fi' => 'Suomi',
        'cs' => 'Čeština',
        'tr' => 'Türkçe',
        'uk' => 'Українська'
      }.freeze

      attr_accessor :available_locales, :default_locale

      def initialize
        @overrides = {}  # { "auth.registration_mode" => "open" }
        @locks = Set.new # { "auth.registration_mode" }
        @available_locales = ['en']
        @default_locale = 'en'
        @custom_locale_display_names = {}
      end

      def locale_display_names=(names)
        @custom_locale_display_names = names || {}
      end

      def locale_display_names
        BUILT_IN_LOCALE_NAMES.merge(@custom_locale_display_names)
      end

      # Set an initializer-level override
      def set(key, value)
        @overrides[key.to_s] = value
      end

      # Lock a setting (visible in admin but not editable)
      def lock(key)
        @locks << key.to_s
      end

      def locked?(key)
        @locks.include?(key.to_s)
      end

      def locked_keys
        @locks.to_a
      end

      # Read initializer override for resolver
      def initializer_value(category, key)
        @overrides["#{category}.#{key}"]
      end
    end
  end
end
