# frozen_string_literal: true

require 'test_helper'

module RSB
  module Admin
    class SessionIdleTimeoutTest < ActionDispatch::IntegrationTest
      include RSB::Admin::Engine.routes.url_helpers
      include RSB::Admin::TestKit::Helpers

      setup do
        RSB::Admin.reset!
        RSB::Settings.reset!
        RSB::Settings.registry.register(RSB::Admin.settings_schema)
        @admin = create_test_admin!(superadmin: true)
        sign_in_admin(@admin)
      end

      teardown do
        RSB::Admin::AdminSession.delete_all
        RSB::Admin::AdminUser.delete_all
        RSB::Admin::Role.delete_all
        RSB::Admin.reset!
        RSB::Settings.reset!
      end

      # --- Idle timeout disabled (default) ---

      test 'no timeout when admin.session_idle_timeout is 0 (default)' do
        # Default is 0 = disabled
        assert_equal 0, RSB::Settings.get('admin.session_idle_timeout')

        # Even with old last_active_at, session should still work
        admin_session = RSB::Admin::AdminSession.last
        admin_session.update_column(:last_active_at, 2.hours.ago)

        get dashboard_path
        assert_response :success
      end

      # --- Idle timeout enabled ---

      test 'session expires when idle longer than timeout' do
        with_settings('admin.session_idle_timeout' => 1800) do # 30 minutes
          admin_session = RSB::Admin::AdminSession.last
          admin_session.update_column(:last_active_at, 31.minutes.ago)

          get dashboard_path
          assert_redirected_to login_path
          follow_redirect!

          # Session should be destroyed
          assert_nil RSB::Admin::AdminSession.find_by(id: admin_session.id)
        end
      end

      test 'session stays active when within timeout window' do
        with_settings('admin.session_idle_timeout' => 1800) do # 30 minutes
          admin_session = RSB::Admin::AdminSession.last
          admin_session.update_column(:last_active_at, 10.minutes.ago)

          get dashboard_path
          assert_response :success

          # Session should still exist
          assert RSB::Admin::AdminSession.find_by(id: admin_session.id).present?
        end
      end

      test 'idle timeout triggers flash alert about inactivity' do
        with_settings('admin.session_idle_timeout' => 600) do # 10 minutes
          admin_session = RSB::Admin::AdminSession.last
          admin_session.update_column(:last_active_at, 11.minutes.ago)

          get dashboard_path
          assert_redirected_to login_path
          follow_redirect!
          assert_match(/inactivity/i, flash[:alert])
        end
      end

      test 'idle timeout destroys the admin session record' do
        with_settings('admin.session_idle_timeout' => 300) do # 5 minutes
          admin_session = RSB::Admin::AdminSession.last
          session_id = admin_session.id
          admin_session.update_column(:last_active_at, 6.minutes.ago)

          assert_difference 'RSB::Admin::AdminSession.count', -1 do
            get dashboard_path
          end

          assert_nil RSB::Admin::AdminSession.find_by(id: session_id)
        end
      end

      test 'active sessions get last_active_at refreshed by track_session_activity' do
        with_settings('admin.session_idle_timeout' => 1800) do
          admin_session = RSB::Admin::AdminSession.last
          old_time = 5.minutes.ago
          admin_session.update_column(:last_active_at, old_time)

          get dashboard_path
          assert_response :success

          # track_session_activity calls touch_activity! which updates last_active_at
          admin_session.reload
          assert admin_session.last_active_at > old_time
        end
      end

      private

      def default_url_options
        { host: 'localhost' }
      end
    end
  end
end
