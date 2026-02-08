# frozen_string_literal: true

require "test_helper"

class AdminTwoFactorSettingTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.registry.register(RSB::Admin.settings_schema)
  end

  test "admin.require_two_factor setting exists with default false" do
    value = RSB::Settings.get("admin.require_two_factor")
    assert_equal false, value
  end

  test "admin.require_two_factor can be set to true" do
    RSB::Settings.set("admin.require_two_factor", true)
    assert_equal true, RSB::Settings.get("admin.require_two_factor")
  end
end
