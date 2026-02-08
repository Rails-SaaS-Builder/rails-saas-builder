require "test_helper"

class RateLimitableTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
  end

  test "rate limits login attempts" do
    11.times do
      post session_path, params: {
        identifier: "test@example.com",
        password: "wrong"
      }
    end

    # The 11th request should be rate limited (limit: 10)
    assert_response :too_many_requests
  end

  test "rate limits registration attempts" do
    6.times do
      post registration_path, params: {
        identifier: "test#{rand(9999)}@example.com",
        password: "short",
        password_confirmation: "short"
      }
    end

    # The 6th request should be rate limited (limit: 5)
    assert_response :too_many_requests
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
