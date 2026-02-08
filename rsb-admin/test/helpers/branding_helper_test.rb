require "test_helper"

class BrandingHelperTest < ActionView::TestCase
  include RSB::Admin::BrandingHelper

  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
  end

  test "rsb_admin_logo_url returns empty string by default" do
    assert_equal "", rsb_admin_logo_url
  end

  test "rsb_admin_logo_url returns set value" do
    RSB::Settings.set("admin.logo_url", "https://example.com/logo.png")
    assert_equal "https://example.com/logo.png", rsb_admin_logo_url
  end

  test "rsb_admin_company_name returns empty string by default" do
    assert_equal "", rsb_admin_company_name
  end

  test "rsb_admin_company_name returns set value" do
    RSB::Settings.set("admin.company_name", "Acme Corp")
    assert_equal "Acme Corp", rsb_admin_company_name
  end

  test "rsb_admin_footer_text returns empty string by default" do
    assert_equal "", rsb_admin_footer_text
  end

  test "rsb_admin_footer_text returns set value" do
    RSB::Settings.set("admin.footer_text", "© 2024 Acme")
    assert_equal "© 2024 Acme", rsb_admin_footer_text
  end
end
