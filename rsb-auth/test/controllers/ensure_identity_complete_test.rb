# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class EnsureIdentityCompleteTest < ActionDispatch::IntegrationTest
      include RSB::Auth::Engine.routes.url_helpers

      setup do
        register_auth_settings
        register_auth_credentials
        Rails.cache.clear
      end

      test 'does not redirect when identity is complete' do
        identity = RSB::Auth::Identity.create!
        identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'complete@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        post session_path, params: { identifier: 'complete@example.com', password: 'password1234' }

        get '/'
        assert_response :success
      end

      test 'does not redirect for unauthenticated users' do
        get '/'
        assert_response :success
      end

      test 'redirects to account edit when identity is incomplete' do
        incomplete_concern = Module.new do
          extend ActiveSupport::Concern
          def complete?
            false
          end
        end

        with_identity_concerns(incomplete_concern) do
          identity = RSB::Auth::Identity.create!
          identity.credentials.create!(
            type: 'RSB::Auth::Credential::EmailPassword',
            identifier: 'incomplete@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )
          post session_path, params: { identifier: 'incomplete@example.com', password: 'password1234' }

          get '/'
          assert_response :redirect
          assert_match %r{/auth/account}, response.location
          assert_equal I18n.t('rsb.auth.account.complete_profile'), flash[:alert]
        end
      end

      test 'does not redirect on auth engine routes (prevents redirect loop)' do
        incomplete_concern = Module.new do
          extend ActiveSupport::Concern
          def complete?
            false
          end
        end

        with_identity_concerns(incomplete_concern) do
          identity = RSB::Auth::Identity.create!
          identity.credentials.create!(
            type: 'RSB::Auth::Credential::EmailPassword',
            identifier: 'engine@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )
          post session_path, params: { identifier: 'engine@example.com', password: 'password1234' }

          get account_path
          assert_response :success
        end
      end

      private

      def default_url_options
        { host: 'localhost' }
      end
    end
  end
end
