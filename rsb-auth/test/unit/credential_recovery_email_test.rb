# frozen_string_literal: true

require 'test_helper'

class CredentialRecoveryEmailTest < ActiveSupport::TestCase
  setup do
    register_auth_settings
    register_all_auth_credentials
    @identity = create_test_identity
  end

  # --- recovery_email normalization ---

  test 'recovery_email is normalized to lowercase and stripped' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: '  User@Example.COM  '
    )
    assert_equal 'user@example.com', cred.recovery_email
  end

  test 'recovery_email nil is preserved' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: nil
    )
    assert_nil cred.recovery_email
  end

  test 'recovery_email blank string is preserved as blank' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: ''
    )
    assert_equal '', cred.recovery_email
  end

  # --- recovery_email validation ---

  test 'recovery_email with valid email format passes' do
    cred = @identity.credentials.build(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'recovery@example.com'
    )
    assert cred.valid?
  end

  test 'recovery_email with invalid format fails validation' do
    cred = @identity.credentials.build(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'not-an-email'
    )
    refute cred.valid?
    assert cred.errors[:recovery_email].any?
  end

  test 'recovery_email blank is allowed (optional field)' do
    cred = @identity.credentials.build(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: ''
    )
    assert cred.valid?
  end

  # --- deliverable_email ---

  test 'deliverable_email returns recovery_email when present' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'recovery@example.com'
    )
    assert_equal 'recovery@example.com', cred.deliverable_email
  end

  test 'deliverable_email returns identifier for email credentials' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert_equal 'user@example.com', cred.deliverable_email
  end

  test 'deliverable_email returns nil for username credential without recovery_email' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: nil
    )
    assert_nil cred.deliverable_email
  end

  test 'deliverable_email prefers recovery_email over identifier for email credential' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'user@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: 'other@example.com'
    )
    assert_equal 'other@example.com', cred.deliverable_email
  end

  test 'deliverable_email returns nil for username with blank recovery_email' do
    cred = @identity.credentials.create!(
      type: 'RSB::Auth::Credential::UsernamePassword',
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234',
      recovery_email: ''
    )
    assert_nil cred.deliverable_email
  end
end
