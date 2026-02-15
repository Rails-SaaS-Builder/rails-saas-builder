# frozen_string_literal: true

require 'test_helper'

class RSB::Auth::Credential::EmailPasswordTest < ActiveSupport::TestCase
  setup do
    register_test_schema('auth', password_min_length: 8)
    @identity = RSB::Auth::Identity.create!
  end

  test 'validates email format' do
    cred = RSB::Auth::Credential::EmailPassword.new(
      identity: @identity,
      identifier: 'not-an-email',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert_not cred.valid?
    assert cred.errors[:identifier].any?
  end

  test 'accepts valid email' do
    cred = RSB::Auth::Credential::EmailPassword.new(
      identity: @identity,
      identifier: 'test@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    assert cred.valid?
  end
end
