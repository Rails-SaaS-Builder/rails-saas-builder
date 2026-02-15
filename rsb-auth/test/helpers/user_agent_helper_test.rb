# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class UserAgentHelperTest < ActiveSupport::TestCase
      include RSB::Auth::UserAgentHelper

      test 'parse_user_agent returns browser and OS for Chrome on macOS' do
        ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        result = parse_user_agent(ua)

        assert_kind_of Hash, result
        assert_match(/Chrome/, result[:browser])
        assert_match(/120/, result[:browser])
        assert_match(/OS X/, result[:os])
      end

      test 'parse_user_agent returns browser and OS for Safari on iOS' do
        ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
        result = parse_user_agent(ua)

        assert_kind_of Hash, result
        assert_match(/Safari/, result[:browser])
        assert_match(/iOS/, result[:os])
      end

      test 'parse_user_agent returns browser and OS for Firefox on Windows' do
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0'
        result = parse_user_agent(ua)

        assert_kind_of Hash, result
        assert_match(/Firefox/, result[:browser])
        assert_match(/Windows/, result[:os])
      end

      test 'parse_user_agent handles nil user agent' do
        result = parse_user_agent(nil)

        assert_equal({ browser: 'Unknown', os: 'Unknown' }, result)
      end

      test 'parse_user_agent handles empty string' do
        result = parse_user_agent('')

        assert_equal({ browser: 'Unknown', os: 'Unknown' }, result)
      end

      test 'parse_user_agent handles whitespace-only string' do
        result = parse_user_agent('   ')

        assert_equal({ browser: 'Unknown', os: 'Unknown' }, result)
      end

      test 'parse_user_agent returns hash with expected keys' do
        ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36'
        result = parse_user_agent(ua)

        assert result.key?(:browser), 'Expected result to have :browser key'
        assert result.key?(:os), 'Expected result to have :os key'
        assert_equal 2, result.keys.size, 'Expected result to have exactly 2 keys'
      end
    end
  end
end
