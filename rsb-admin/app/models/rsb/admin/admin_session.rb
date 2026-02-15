# frozen_string_literal: true

module RSB
  module Admin
    # Represents an active admin session with device and location tracking.
    #
    # Each sign-in creates an AdminSession record with a unique token stored in
    # the cookie session. The token replaces the plain user ID for security.
    # Device information is parsed from the User-Agent header.
    #
    # @example Create a session from a request
    #   session = AdminSession.create_from_request!(admin_user: user, request: request)
    #   session.session_token # => "abc123..."
    #   session.browser       # => "Chrome"
    #   session.os            # => "macOS"
    #
    class AdminSession < ApplicationRecord
      belongs_to :admin_user

      validates :session_token, presence: true, uniqueness: true
      validates :last_active_at, presence: true

      before_validation :generate_session_token, on: :create

      # Parses a User-Agent string into browser, OS, and device type.
      # Uses simple regex matching — no external gem dependency.
      #
      # @param user_agent [String, nil] the raw User-Agent header
      # @return [Hash{Symbol => String}] keys: :browser, :os, :device_type
      #
      # @example
      #   AdminSession.parse_user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      #   # => { browser: "Chrome", os: "macOS", device_type: "desktop" }
      def self.parse_user_agent(user_agent)
        ua = user_agent.to_s

        browser = case ua
                  when %r{Edg/}i then 'Edge'
                  when %r{OPR/}i, /Opera/i then 'Opera'
                  when /Chrome/i then 'Chrome'
                  when /Firefox/i then 'Firefox'
                  when /Safari/i then 'Safari'
                  else 'Unknown'
                  end

        os = case ua
             when /Windows/i then 'Windows'
             when /iPhone|iPad/i then 'iOS'
             when /Android/i then 'Android'
             when /Macintosh|Mac OS/i then 'macOS'
             when /Linux/i then 'Linux'
             else 'Unknown'
             end

        device_type = case ua
                      when /Mobile|iPhone|Android.*Mobile/i then 'mobile'
                      when /iPad|Tablet|Android(?!.*Mobile)/i then 'tablet'
                      else 'desktop'
                      end

        { browser: browser, os: os, device_type: device_type }
      end

      # Creates a session record for the given admin user from a request.
      #
      # Parses the User-Agent header for device info, records IP address,
      # and generates a unique session token.
      #
      # @param admin_user [AdminUser] the authenticated admin
      # @param request [ActionDispatch::Request] the current request
      # @return [AdminSession] the persisted session record
      # @raise [ActiveRecord::RecordInvalid] if validation fails
      def self.create_from_request!(admin_user:, request:)
        parsed = parse_user_agent(request.user_agent)

        create!(
          admin_user: admin_user,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          browser: parsed[:browser],
          os: parsed[:os],
          device_type: parsed[:device_type],
          last_active_at: Time.current
        )
      end

      # Checks if this session matches the given token (i.e., is the "current" session).
      #
      # @param token [String] the session token from the cookie
      # @return [Boolean]
      def current?(token)
        session_token == token
      end

      # Updates last_active_at without triggering callbacks or updating updated_at.
      #
      # @return [void]
      def touch_activity!
        update_column(:last_active_at, Time.current)
      end

      private

      def generate_session_token
        self.session_token ||= SecureRandom.urlsafe_base64(32)
      end
    end
  end
end
