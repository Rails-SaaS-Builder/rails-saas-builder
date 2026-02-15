# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class IdentityTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
      end

      test 'default status is active' do
        identity = RSB::Auth::Identity.create!
        assert_equal 'active', identity.status
      end

      test 'supports status enum' do
        identity = RSB::Auth::Identity.create!
        assert identity.active?

        identity.update!(status: :suspended)
        assert identity.suspended?

        identity.update!(status: :deactivated)
        assert identity.deactivated?
      end

      test 'active scope returns only active identities' do
        active = RSB::Auth::Identity.create!(status: :active)
        suspended = RSB::Auth::Identity.create!(status: :suspended)

        result = RSB::Auth::Identity.active
        assert_includes result, active
        assert_not_includes result, suspended
      end

      test 'primary_credential returns first credential by created_at' do
        identity = RSB::Auth::Identity.create!
        cred = identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_equal cred, identity.primary_credential
      end

      test 'primary_identifier returns identifier of primary credential' do
        identity = RSB::Auth::Identity.create!
        identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_equal 'test@example.com', identity.primary_identifier
      end

      test 'primary_identifier returns nil when no credentials' do
        identity = RSB::Auth::Identity.create!
        assert_nil identity.primary_identifier
      end

      test 'destroying identity destroys credentials and sessions' do
        identity = RSB::Auth::Identity.create!
        identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_difference ['RSB::Auth::Credential.count', 'RSB::Auth::Identity.count'], -1 do
          identity.destroy!
        end
      end

      test 'after_identity_created lifecycle handler fires on create' do
        called_with = nil
        custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
          define_method(:after_identity_created) { |identity| called_with = identity }
        end
        stub_name = 'RSB::Auth::TestIdentityCreatedHandler'
        RSB::Auth.const_set(:TestIdentityCreatedHandler, custom_handler)
        RSB::Auth.configuration.lifecycle_handler = stub_name

        identity = RSB::Auth::Identity.create!
        assert_equal identity, called_with
      ensure
        RSB::Auth.configuration.lifecycle_handler = nil
        if RSB::Auth.const_defined?(:TestIdentityCreatedHandler)
          RSB::Auth.send(:remove_const, :TestIdentityCreatedHandler)
        end
      end

      test 'lifecycle handler no-op when no handler configured' do
        RSB::Auth.configuration.lifecycle_handler = nil

        assert_nothing_raised do
          RSB::Auth::Identity.create!
        end
      end

      test 'complete? returns true by default' do
        identity = RSB::Auth::Identity.create!
        assert identity.complete?
      end

      test 'does NOT include Entitleable' do
        assert_not(RSB::Auth::Identity.ancestors.map(&:name).any? { |n| n&.include?('Entitleable') })
      end
    end
  end
end
