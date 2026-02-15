# frozen_string_literal: true

require 'rack/request'
require 'rack/response'

module RSB
  module Settings
    # Rack middleware that resolves locale from cookie, Accept-Language header,
    # or configured default. Also handles POST /rsb/locale to set the locale cookie.
    #
    # Resolution chain (highest priority first):
    #   1. Cookie (rsb_locale)
    #   2. Accept-Language header (best match from available_locales)
    #   3. Configured default_locale
    #
    # The middleware auto-inserts into the Rails middleware stack via the
    # rsb_settings engine initializer. Applies to all requests (host app + engines).
    #
    # @example Remove from host app if not wanted
    #   config.middleware.delete RSB::Settings::LocaleMiddleware
    #
    class LocaleMiddleware
      COOKIE_NAME = 'rsb_locale'
      COOKIE_MAX_AGE = 31_536_000 # 1 year in seconds
      LOCALE_PATH = '/rsb/locale'

      def initialize(app)
        @app = app
      end

      # @param env [Hash] Rack environment
      # @return [Array] Rack response tuple [status, headers, body]
      def call(env)
        request = Rack::Request.new(env)

        # Handle locale switching endpoint
        return handle_locale_change(request) if request.post? && request.path_info == LOCALE_PATH

        # Resolve and set locale for this request
        locale = resolve_locale(request)
        I18n.locale = locale
        env['rsb.locale'] = locale.to_s

        @app.call(env)
      ensure
        I18n.locale = I18n.default_locale
      end

      private

      # Handles POST /rsb/locale: validates locale, sets cookie, redirects back.
      #
      # @param request [Rack::Request]
      # @return [Array] Rack response tuple
      def handle_locale_change(request)
        locale = request.params['locale'].to_s.strip
        available = RSB::Settings.available_locales

        # Empty locale = redirect without setting cookie
        return redirect_response(redirect_path(request)) if locale.empty?

        # Invalid locale falls back to default
        locale = RSB::Settings.default_locale unless available.include?(locale)

        response = Rack::Response.new
        response.set_cookie(COOKIE_NAME, {
                              value: locale,
                              path: '/',
                              max_age: COOKIE_MAX_AGE,
                              same_site: :lax,
                              httponly: false
                            })
        response.redirect(redirect_path(request))
        response.finish
      end

      # Resolves locale from cookie, Accept-Language, or default.
      #
      # @param request [Rack::Request]
      # @return [String] resolved locale code
      def resolve_locale(request)
        available = RSB::Settings.available_locales
        default = RSB::Settings.default_locale

        # 1. Cookie
        cookie_locale = request.cookies[COOKIE_NAME].to_s.strip
        return cookie_locale if cookie_locale.present? && available.include?(cookie_locale)

        # 2. Accept-Language header
        accept_locale = parse_accept_language(
          request.env['HTTP_ACCEPT_LANGUAGE'],
          available
        )
        return accept_locale if accept_locale

        # 3. Default
        default
      end

      # Parses the Accept-Language header and returns the best match.
      #
      # @param header [String, nil] Accept-Language header value
      # @param available [Array<String>] available locale codes
      # @return [String, nil] best matching locale or nil
      def parse_accept_language(header, available)
        return nil if header.nil? || header.empty?

        locales = header.split(',').filter_map do |part|
          part = part.strip
          next if part.empty?

          lang, quality_str = part.split(';', 2)
          lang = lang.to_s.split('-').first.to_s.downcase.strip
          next if lang.empty?

          quality = if quality_str
                      q_match = quality_str.match(/q\s*=\s*([\d.]+)/)
                      q_match ? q_match[1].to_f : 1.0
                    else
                      1.0
                    end

          [lang, quality]
        end

        locales
          .sort_by { |_, q| -q }
          .each { |lang, _| return lang if available.include?(lang) }

        nil
      end

      # Determines a safe redirect path from request params or Referer.
      #
      # @param request [Rack::Request]
      # @return [String] safe redirect path (always starts with "/")
      def redirect_path(request)
        # 1. redirect_to param
        redirect_to = request.params['redirect_to'].to_s
        return redirect_to if redirect_to.start_with?('/') && !redirect_to.start_with?('//')

        # 2. Referer header (extract path only)
        if request.referrer.present?
          begin
            uri = URI.parse(request.referrer)
            path = uri.path.to_s
            return path if path.start_with?('/')
          rescue URI::InvalidURIError
            # fall through
          end
        end

        # 3. Fallback
        '/'
      end

      # Creates a simple redirect response without setting a cookie.
      #
      # @param path [String] redirect target
      # @return [Array] Rack response tuple
      def redirect_response(path)
        response = Rack::Response.new
        response.redirect(path)
        response.finish
      end
    end
  end
end
