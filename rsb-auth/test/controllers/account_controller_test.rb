# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class AccountControllerTest < ActionDispatch::IntegrationTest
      include RSB::Auth::Engine.routes.url_helpers

      setup do
        register_auth_settings
        register_auth_credentials
        Rails.cache.clear
        @identity = RSB::Auth::Identity.create!(metadata: { 'name' => 'Test' })
        @credential = @identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'account@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        post session_path, params: { identifier: 'account@example.com', password: 'password1234' }
        @session = @identity.sessions.reload.last
      end

      # --- Authentication ---

      test 'show requires authentication' do
        cookies.delete('rsb_session_token')
        get account_path
        assert_response :redirect
      end

      # --- show ---

      test 'show renders account page' do
        get account_path
        assert_response :success
        assert_select 'h2', /Account/
        assert_response_includes 'Login Methods'
        assert_response_includes 'Active Sessions'
      end

      test 'show lists active credentials as login methods' do
        get account_path
        assert_response :success
        assert_response_includes 'account@example.com'
        assert_response_includes 'Email Password'
      end

      test 'show lists active sessions with current session highlighted' do
        get account_path
        assert_response :success
        assert_response_includes 'Current'
      end

      test 'show renders identity fields partial' do
        get account_path
        assert_response :success
        # The partial renders (even if empty — no error raised)
      end

      test 'show hides delete section when account_deletion_enabled is false' do
        with_settings('auth.account_deletion_enabled' => false) do
          get account_path
          assert_response :success
          refute_response_includes 'Delete Account'
        end
      end

      test 'show shows delete section when account_deletion_enabled is true' do
        with_settings('auth.account_deletion_enabled' => true) do
          get account_path
          assert_response :success
          assert_response_includes 'Delete Account'
        end
      end

      test 'show is disabled when account_enabled is false' do
        with_settings('auth.account_enabled' => false) do
          get account_path
          assert_response :redirect
          follow_redirect!
          assert_equal I18n.t('rsb.auth.account.disabled'), flash[:alert]
        end
      end

      # --- update ---

      test 'update with valid params succeeds' do
        patch account_path, params: { identity: { metadata: { 'name' => 'Updated' } } }
        assert_response :redirect
        assert_redirected_to account_path
        assert_equal({ 'name' => 'Updated' }, @identity.reload.metadata)
        assert_equal I18n.t('rsb.auth.account.updated'), flash[:notice]
      end

      test 'update with invalid params re-renders show' do
        RSB::Auth.configuration.permitted_account_params = %i[metadata status]
        patch account_path, params: { identity: { status: 'bogus' } }
        assert_response :unprocessable_entity
      ensure
        RSB::Auth.configuration.permitted_account_params = [:metadata]
      end

      # --- confirm_destroy ---

      test 'confirm_destroy requires authentication' do
        cookies.delete('rsb_session_token')
        get confirm_destroy_account_path
        assert_response :redirect
      end

      test 'confirm_destroy renders password form' do
        with_settings('auth.account_deletion_enabled' => true) do
          get confirm_destroy_account_path
          assert_response :success
          assert_select "input[name='password']"
        end
      end

      test 'confirm_destroy redirects when deletion disabled' do
        with_settings('auth.account_deletion_enabled' => false) do
          get confirm_destroy_account_path
          assert_response :redirect
          assert_redirected_to account_path
        end
      end

      # --- destroy ---

      test 'destroy with correct password deletes account' do
        with_settings('auth.account_deletion_enabled' => true) do
          delete account_path, params: { password: 'password1234' }
          assert_response :redirect
          assert_redirected_to new_session_path
          assert_equal 'deleted', @identity.reload.status
          assert_not_nil @identity.deleted_at
        end
      end

      test 'destroy with wrong password re-renders confirm_destroy' do
        with_settings('auth.account_deletion_enabled' => true) do
          delete account_path, params: { password: 'wrongpassword' }
          assert_response :unprocessable_entity
        end
      end

      test 'destroy clears session cookie' do
        with_settings('auth.account_deletion_enabled' => true) do
          delete account_path, params: { password: 'password1234' }
          # After redirect, attempting to access account should redirect to login
          follow_redirect!
          get account_path
          assert_response :redirect # redirects to login — session is gone
        end
      end

      test 'destroy when deletion disabled redirects with alert' do
        with_settings('auth.account_deletion_enabled' => false) do
          delete account_path, params: { password: 'password1234' }
          assert_response :redirect
          assert_redirected_to account_path
          assert_equal I18n.t('rsb.auth.account.deletion_disabled'), flash[:alert]
        end
      end

      private

      def default_url_options
        { host: 'localhost' }
      end

      def assert_response_includes(text)
        assert_includes response.body, text, "Expected response body to include '#{text}'"
      end

      def refute_response_includes(text)
        refute_includes response.body, text, "Expected response body NOT to include '#{text}'"
      end
    end
  end
end
