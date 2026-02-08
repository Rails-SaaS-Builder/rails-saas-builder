require "test_helper"

class FlashMessagesTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
  end

  test "notice flash renders with success styling" do
    # Login redirect sets a notice flash
    follow_redirect!
    assert_response :success
    assert_select ".bg-rsb-success-bg"
    assert_select ".text-rsb-success-text"
  end

  test "alert flash renders with danger styling" do
    # Failed login sets an alert flash
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: @admin.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_select ".bg-rsb-danger-bg"
    assert_select ".text-rsb-danger-text"
  end

  test "flash has dismiss button" do
    follow_redirect!
    assert_select "button[onclick*='remove']"
  end

  test "flash has icon" do
    follow_redirect!
    # Check that an SVG icon is present inside the flash
    assert_select ".bg-rsb-success-bg svg"
  end
end
