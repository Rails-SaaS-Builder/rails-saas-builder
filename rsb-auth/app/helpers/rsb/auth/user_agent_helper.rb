require "useragent"

module RSB
  module Auth
    module UserAgentHelper
      def parse_user_agent(user_agent)
        return { browser: "Unknown", os: "Unknown" } if user_agent.blank?

        parsed = UserAgent.parse(user_agent)
        browser = [parsed.browser, parsed.version&.to_s&.split(".")&.first].compact.join(" ")
        os = parsed.os.presence || "Unknown"

        {
          browser: browser.presence || "Unknown",
          os: os.presence || "Unknown"
        }
      end
    end
  end
end
