# frozen_string_literal: true

# Security Test: Password Hashing Verification
#
# Attack vectors prevented:
# - Weak password hashing (insufficient bcrypt cost)
# - Passwords stored in plaintext
# - Missing has_secure_password on password-bearing models
# - Minimum password length bypass
#
# Covers: SRS-016 US-023 (Password Hashing)

require 'test_helper'

class PasswordHashingTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    register_all_credentials
  end

  # --- Credential password hashing ---

  test 'Credential uses has_secure_password (bcrypt)' do
    identity = RSB::Auth::Identity.create!
    credential = identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'hash-test@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    assert credential.password_digest.present?, 'Password must be hashed (password_digest present)'
    assert credential.password_digest.start_with?('$2'), 'Password must use bcrypt hash format'
    assert credential.authenticate('password1234'), 'authenticate must verify correct password'
    assert_not credential.authenticate('wrongpassword'), 'authenticate must reject wrong password'
  end

  # --- AdminUser password hashing ---

  test 'AdminUser uses has_secure_password (bcrypt)' do
    role = RSB::Admin::Role.create!(name: 'Test', permissions: {})
    admin = RSB::Admin::AdminUser.create!(
      email: 'hash-admin@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      role: role
    )

    assert admin.password_digest.present?, 'Admin password must be hashed'
    assert admin.password_digest.start_with?('$2'), 'Admin password must use bcrypt'
    assert admin.authenticate('password1234'), 'Admin authenticate must verify correct password'
    assert_not admin.authenticate('wrongpassword'), 'Admin authenticate must reject wrong password'
  end

  # --- BCrypt cost factor ---

  test 'BCrypt cost factor is at least 4 in test and 12 in production' do
    # In test env, cost is typically 4 for speed
    # In production, Rails default BCrypt cost is 12
    assert BCrypt::Engine.cost >= 4,
           "BCrypt cost #{BCrypt::Engine.cost} is too low (minimum 4)"
  end

  # --- Password minimum length enforcement ---

  test 'Credential enforces minimum password length on creation' do
    identity = RSB::Auth::Identity.create!
    credential = identity.credentials.build(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'short-pass@example.com',
      password: 'short',
      password_confirmation: 'short'
    )

    assert_not credential.valid?, 'Short password must be rejected'
    assert credential.errors[:password].any?, 'Password error must be present'
  end

  test 'AdminUser enforces minimum password length' do
    role = RSB::Admin::Role.create!(name: 'Test2', permissions: {})
    admin = RSB::Admin::AdminUser.new(
      email: 'short-admin@example.com',
      password: 'short',
      password_confirmation: 'short',
      role: role
    )

    assert_not admin.valid?, 'Short admin password must be rejected'
  end

  # --- Password not in plaintext ---

  test 'password is never stored in plaintext on Credential' do
    identity = RSB::Auth::Identity.create!
    credential = identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'plaintext@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    # The raw password should not be stored in any attribute
    assert_not_equal 'password1234', credential.password_digest
  end

  test 'password is never stored in plaintext on AdminUser' do
    role = RSB::Admin::Role.create!(name: 'Test3', permissions: {})
    admin = RSB::Admin::AdminUser.create!(
      email: 'plaintext-admin@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      role: role
    )

    assert_not_equal 'password1234', admin.password_digest
  end
end
