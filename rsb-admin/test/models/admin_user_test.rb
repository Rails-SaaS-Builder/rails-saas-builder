# frozen_string_literal: true

require 'test_helper'

class AdminUserTest < ActiveSupport::TestCase
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
  end

  test 'valid admin user' do
    admin = RSB::Admin::AdminUser.new(
      email: 'admin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
    assert admin.valid?
  end

  test 'requires email' do
    admin = RSB::Admin::AdminUser.new(password: 'password123', password_confirmation: 'password123')
    refute admin.valid?
    assert_includes admin.errors[:email], "can't be blank"
  end

  test 'requires unique email (case insensitive)' do
    RSB::Admin::AdminUser.create!(email: 'admin@example.com', password: 'password123',
                                  password_confirmation: 'password123', role: @role)
    admin = RSB::Admin::AdminUser.new(email: 'ADMIN@example.com', password: 'password123',
                                      password_confirmation: 'password123', role: @role)
    refute admin.valid?
    assert_includes admin.errors[:email], 'has already been taken'
  end

  test 'requires valid email format' do
    admin = RSB::Admin::AdminUser.new(email: 'not-an-email', password: 'password123',
                                      password_confirmation: 'password123')
    refute admin.valid?
    assert_includes admin.errors[:email], 'is invalid'
  end

  test 'requires password minimum 8 characters' do
    admin = RSB::Admin::AdminUser.new(email: 'admin@example.com', password: 'short', password_confirmation: 'short')
    refute admin.valid?
    assert admin.errors[:password].any?
  end

  test 'does not require password on update if not provided' do
    admin = RSB::Admin::AdminUser.create!(email: 'admin@example.com', password: 'password123',
                                          password_confirmation: 'password123', role: @role)
    admin.email = 'new@example.com'
    assert admin.valid?
  end

  test 'authenticates with correct password' do
    admin = RSB::Admin::AdminUser.create!(email: 'admin@example.com', password: 'password123',
                                          password_confirmation: 'password123', role: @role)
    assert admin.authenticate('password123')
    refute admin.authenticate('wrong')
  end

  test 'normalizes email' do
    admin = RSB::Admin::AdminUser.create!(email: '  ADMIN@Example.COM  ', password: 'password123',
                                          password_confirmation: 'password123', role: @role)
    assert_equal 'admin@example.com', admin.email
  end

  test 'record_sign_in! updates timestamp and ip' do
    admin = RSB::Admin::AdminUser.create!(email: 'admin@example.com', password: 'password123',
                                          password_confirmation: 'password123', role: @role)
    assert_nil admin.last_sign_in_at
    assert_nil admin.last_sign_in_ip

    admin.record_sign_in!(ip: '127.0.0.1')
    admin.reload

    assert_not_nil admin.last_sign_in_at
    assert_equal '127.0.0.1', admin.last_sign_in_ip
  end

  test 'can? delegates to role' do
    editor_role = RSB::Admin::Role.create!(name: "Editor-#{SecureRandom.hex(4)}", permissions: {
                                             'articles' => %w[index show]
                                           })
    admin = RSB::Admin::AdminUser.create!(email: 'editor@example.com', password: 'password123',
                                          password_confirmation: 'password123', role: editor_role)

    assert admin.can?('articles', 'index')
    refute admin.can?('articles', 'destroy')
    refute admin.can?('settings', 'index')
  end

  test 'can? returns false when role is nil (no role = no access)' do
    admin = RSB::Admin::AdminUser.create!(email: 'noRole@example.com', password: 'password123',
                                          password_confirmation: 'password123')
    assert_nil admin.role

    refute admin.can?('articles', 'index')
    refute admin.can?('dashboard', 'index')
    refute admin.can?('anything', 'any_action')
  end

  test 'belongs_to role is optional' do
    admin = RSB::Admin::AdminUser.new(email: 'admin@example.com', password: 'password123',
                                      password_confirmation: 'password123')
    assert admin.valid?
  end
end
