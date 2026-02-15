# frozen_string_literal: true

require 'test_helper'

class AuthorizationHelperTest < ActionView::TestCase
  include RSB::Admin::AuthorizationHelper

  # Provides current_admin_user for the helper under test.
  # Each test sets @current_admin to control the return value.
  def current_admin_user
    @current_admin
  end

  test 'rsb_admin_can? returns false when no current_admin_user' do
    @current_admin = nil
    refute rsb_admin_can?('dashboard', 'index')
  end

  test 'rsb_admin_can? delegates to current_admin_user.can?' do
    role = RSB::Admin::Role.create!(
      name: "Helper Test #{SecureRandom.hex(4)}",
      permissions: { 'dashboard' => ['index'] }
    )
    @current_admin = RSB::Admin::AdminUser.create!(
      email: "helper-test-#{SecureRandom.hex(4)}@example.com",
      password: 'password-secure-123',
      password_confirmation: 'password-secure-123',
      role: role
    )

    assert rsb_admin_can?('dashboard', 'index')
    refute rsb_admin_can?('roles', 'index')
  end
end
