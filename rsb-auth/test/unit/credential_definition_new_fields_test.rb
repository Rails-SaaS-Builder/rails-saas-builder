# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class CredentialDefinitionNewFieldsTest < ActiveSupport::TestCase
      test 'accepts icon, form_partial, and redirect_url' do
        defn = RSB::Auth::CredentialDefinition.new(
          key: :email_password,
          class_name: 'RSB::Auth::Credential::EmailPassword',
          authenticatable: true,
          registerable: true,
          label: 'Email & Password',
          icon: 'mail',
          form_partial: 'rsb/auth/credentials/email_password',
          redirect_url: nil
        )

        assert_equal 'mail', defn.icon
        assert_equal 'rsb/auth/credentials/email_password', defn.form_partial
        assert_nil defn.redirect_url
      end

      test 'defaults icon, form_partial, and redirect_url to nil' do
        defn = RSB::Auth::CredentialDefinition.new(
          key: :test,
          class_name: 'TestClass'
        )

        assert_nil defn.icon
        assert_nil defn.form_partial
        assert_nil defn.redirect_url
      end

      test 'redirect_url is set for redirect-based credentials' do
        defn = RSB::Auth::CredentialDefinition.new(
          key: :google_oauth,
          class_name: 'TestOAuth',
          label: 'Sign in with Google',
          icon: 'globe',
          redirect_url: '/auth/google'
        )

        assert_equal '/auth/google', defn.redirect_url
        assert_nil defn.form_partial
      end

      test 'backward compat — existing definitions without new fields still work' do
        defn = RSB::Auth::CredentialDefinition.new(
          key: :email_password,
          class_name: 'RSB::Auth::Credential::EmailPassword',
          authenticatable: true,
          registerable: true,
          label: 'Email & Password'
        )

        assert_equal :email_password, defn.key
        assert_equal 'RSB::Auth::Credential::EmailPassword', defn.class_name
        assert defn.authenticatable
        assert defn.registerable
        assert_equal 'Email & Password', defn.label
        assert defn.valid?
      end

      test 'valid? still works with new fields' do
        defn = RSB::Auth::CredentialDefinition.new(
          key: :test,
          class_name: 'TestClass',
          icon: 'star',
          form_partial: 'test/partial'
        )
        assert defn.valid?
      end
    end
  end
end
