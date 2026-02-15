# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    module Admin
      class UsageCountersControllerTest < ActionDispatch::IntegrationTest
        include RSB::Settings::TestHelper
        include RSB::Entitlements::TestHelper
        include RSB::Admin::TestKit::Helpers

        setup do
          register_all_settings
          register_all_admin_categories
          @admin = create_test_admin!(superadmin: true)
          sign_in_admin(@admin)

          register_test_provider(key: :admin)
          @org = Organization.create!(name: 'Test Org')
          @plan = create_test_plan(limits: {
                                     'api_calls' => { 'limit' => 1000, 'period' => 'daily' },
                                     'projects' => { 'limit' => 10, 'period' => nil }
                                   })
        end

        # Helper to register admin categories (needed since on_load hooks only fire once)
        def register_all_settings
          RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
          RSB::Settings.registry.register(RSB::Admin.settings_schema) if RSB::Admin.respond_to?(:settings_schema)
        end

        def register_all_admin_categories
          RSB::Admin.registry.register_category 'Billing' do
            page :usage_counters,
                 label: 'Usage Monitoring',
                 icon: 'bar-chart',
                 controller: 'rsb/entitlements/admin/usage_counters',
                 actions: [
                   { key: :index, label: 'Overview' },
                   { key: :trend, label: 'Trend' }
                 ]
          end
        end

        # --- index ---

        test 'index renders usage counters table' do
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-13',
                                    current_value: 42, limit: 1000)

          get '/admin/usage_counters'
          assert_response :success
          assert_match 'api_calls', response.body
          assert_match '42', response.body
          assert_match '1000', response.body
        end

        test 'index filters by metric' do
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-13',
                                    current_value: 42, limit: 1000)
          create_test_usage_counter(countable: @org, metric: 'projects', plan: @plan, period_key: '__cumulative__',
                                    current_value: 5, limit: 10)

          get '/admin/usage_counters', params: { metric: 'api_calls' }
          assert_response :success
          # Should show api_calls row with value 42
          assert_match 'api_calls', response.body
          assert_match '>42<', response.body
          # Should not show projects row with value 5
          refute_match '>5<', response.body
        end

        test 'index shows empty state when no counters' do
          get '/admin/usage_counters'
          assert_response :success
          assert_match(/no usage counters/i, response.body)
        end

        # --- trend ---

        test 'trend renders chart for specified metric' do
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-11',
                                    current_value: 100, limit: 1000)
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-12',
                                    current_value: 200, limit: 1000)
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-13',
                                    current_value: 300, limit: 1000)

          get '/admin/usage_counters/trend', params: { metric: 'api_calls' }
          assert_response :success
          assert_match 'api_calls', response.body
          # Chart should contain period keys
          assert_match '2026-02-11', response.body
          assert_match '2026-02-12', response.body
          assert_match '2026-02-13', response.body
        end

        test 'trend shows metric selection when no metric specified' do
          create_test_usage_counter(countable: @org, metric: 'api_calls', plan: @plan, period_key: '2026-02-13',
                                    current_value: 42, limit: 1000)

          get '/admin/usage_counters/trend'
          assert_response :success
          assert_match 'api_calls', response.body # metric should appear in selector
        end

        test 'trend shows empty state when no data for metric' do
          get '/admin/usage_counters/trend', params: { metric: 'nonexistent' }
          assert_response :success
          assert_match(/no data/i, response.body)
        end

        # --- removed actions ---

        test 'reset_all action no longer exists' do
          # The action should not exist - should get a 404 or error
          post '/admin/usage_counters/reset_all'
          assert_response :not_found
        end
      end
    end
  end
end
