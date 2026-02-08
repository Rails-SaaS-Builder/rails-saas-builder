require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  test "default values" do
    config = RSB::Admin::Configuration.new
    assert_equal true, config.enabled
    assert_equal "Admin", config.app_name
    assert_equal "", config.company_name
    assert_equal "", config.logo_url
    assert_equal "", config.footer_text
    assert_equal 25, config.per_page
    assert_equal :default, config.theme
    assert_nil config.view_overrides_path
    assert_equal "rsb/admin/application", config.layout
  end

  test "attribute accessors work" do
    config = RSB::Admin::Configuration.new
    config.enabled = false
    config.app_name = "My Admin"
    config.company_name = "Acme Corp"
    config.logo_url = "/images/logo.svg"
    config.footer_text = "© 2024 Acme"
    config.per_page = 50
    config.theme = :modern

    assert_equal false, config.enabled
    assert_equal "My Admin", config.app_name
    assert_equal "Acme Corp", config.company_name
    assert_equal "/images/logo.svg", config.logo_url
    assert_equal "© 2024 Acme", config.footer_text
    assert_equal 50, config.per_page
    assert_equal :modern, config.theme
  end

  test "default mailer_sender is no-reply@example.com" do
    config = RSB::Admin::Configuration.new
    assert_equal "no-reply@example.com", config.mailer_sender
  end

  test "default email_verification_expiry is 24 hours" do
    config = RSB::Admin::Configuration.new
    assert_equal 24.hours, config.email_verification_expiry
  end

  test "mailer_sender is configurable" do
    config = RSB::Admin::Configuration.new
    config.mailer_sender = "admin@myapp.com"
    assert_equal "admin@myapp.com", config.mailer_sender
  end

  test "email_verification_expiry is configurable" do
    config = RSB::Admin::Configuration.new
    config.email_verification_expiry = 1.hour
    assert_equal 1.hour, config.email_verification_expiry
  end
end
