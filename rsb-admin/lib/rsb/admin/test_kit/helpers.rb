# frozen_string_literal: true

module RSB
  module Admin
    module TestKit
      module Helpers
        extend ActiveSupport::Concern

        included do
          teardown do
            RSB::Admin.reset!
          end
        end

        def create_test_admin!(permissions: nil, superadmin: false, no_role: false, email: nil,
                               password: 'test-password-secure')
          email ||= "test-admin-#{SecureRandom.hex(4)}@example.com"

          if no_role
            return RSB::Admin::AdminUser.create!(
              email: email,
              password: password,
              password_confirmation: password
            )
          end

          if superadmin || permissions.nil?
            role = RSB::Admin::Role.create!(
              name: "Test Superadmin #{SecureRandom.hex(4)}",
              permissions: { '*' => ['*'] }
            )
          else
            # For empty permissions, use a sentinel value that passes validation
            perm = permissions.empty? ? { '_none' => [] } : permissions
            role = RSB::Admin::Role.create!(
              name: "Test Role #{SecureRandom.hex(4)}",
              permissions: perm
            )
          end

          RSB::Admin::AdminUser.create!(
            email: email,
            password: password,
            password_confirmation: password,
            role: role
          )
        end

        def sign_in_admin(admin, password: 'test-password-secure')
          post rsb_admin.login_path, params: { email: admin.email, password: password }
        end

        def assert_admin_authorized
          assert_response :success
        end

        # Assert that admin access was denied.
        #
        # Checks that the response is either a redirect (302, for unauthenticated users
        # redirected to login) or a forbidden response (403, for authenticated users
        # without permission). After RFC-002, 403 responses include a rendered
        # forbidden page body.
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if response is not 302 or 403
        #
        # @example Verify a restricted admin is denied
        #   restricted = create_test_admin!(permissions: { "dashboard" => ["index"] })
        #   sign_in_admin(restricted)
        #   get "/admin/roles"
        #   assert_admin_denied
        def assert_admin_denied
          assert_includes [302, 403], response.status
        end

        # Assert that the forbidden page is rendered with proper content.
        #
        # Verifies that the response has a 403 status and contains the expected
        # forbidden page elements: "Access Denied" title and explanation message.
        # Optionally checks for the presence or absence of the "Go to Dashboard" link.
        #
        # @param dashboard_link [Boolean, nil] if true, asserts dashboard link is present;
        #   if false, asserts it's absent; if nil, doesn't check (default: nil)
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if forbidden page is not rendered correctly
        #
        # @example Basic forbidden page check
        #   get "/admin/roles"
        #   assert_admin_forbidden_page
        #
        # @example Verify no dashboard link for no-role user
        #   get "/admin/dashboard"
        #   assert_admin_forbidden_page(dashboard_link: false)
        #
        # @example Verify dashboard link present
        #   get "/admin/roles"
        #   assert_admin_forbidden_page(dashboard_link: true)
        def assert_admin_forbidden_page(dashboard_link: nil)
          assert_response :forbidden

          # Use assert_select to properly handle HTML entities
          assert_select 'h1', text: I18n.t('rsb.admin.shared.access_denied'),
                              message: "Expected 'Access Denied' title in forbidden page"
          assert_select 'p', text: I18n.t('rsb.admin.shared.access_denied_message'),
                             message: 'Expected explanation message in forbidden page'

          return if dashboard_link.nil?

          if dashboard_link
            assert_select 'a', text: I18n.t('rsb.admin.shared.go_to_dashboard'),
                               message: "Expected 'Go to Dashboard' link in forbidden page"
          else
            assert_select 'a', text: I18n.t('rsb.admin.shared.go_to_dashboard'), count: 0,
                               message: "Expected NO 'Go to Dashboard' link in forbidden page"
          end
        end

        def assert_admin_resource_registered(model_class, category:)
          registration = RSB::Admin.registry.find_resource(model_class)
          assert registration, "#{model_class} not registered in admin"
          assert_equal category, registration.category_name
        end

        def with_fresh_admin_registry
          old_registry = RSB::Admin.registry
          RSB::Admin.instance_variable_set(:@registry, RSB::Admin::Registry.new)
          yield RSB::Admin.registry
        ensure
          RSB::Admin.instance_variable_set(:@registry, old_registry)
        end

        # Assert that a column header appears in the response body.
        #
        # This method verifies that a table column with the given label is rendered
        # in the current response. It uses `assert_select` to check for a `<th>` tag
        # containing the label text (case-insensitive). Useful for verifying that
        # registered columns appear in resource index views.
        #
        # @param label [String] the column header text to look for
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if the column header is not found
        #
        # @example Verify email column renders
        #   get "/admin/users"
        #   assert_admin_column_rendered("Email")
        #
        # @example Verify custom column label
        #   get "/admin/identities"
        #   assert_admin_column_rendered("Identity Email")
        def assert_admin_column_rendered(label)
          assert_select 'th', text: /#{Regexp.escape(label)}/i,
                              message: "Expected column '#{label}' in table header"
        end

        # Assert that a filter input exists in the response.
        #
        # This method verifies that a filter form field with the given key is rendered
        # in the current response. It uses `assert_select` to check for an input/select
        # element with a name attribute matching the filter parameter format `q[key]`.
        # Useful for verifying that registered filters appear in resource index views.
        #
        # @param key [String, Symbol] the filter key to look for
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if the filter input is not found
        #
        # @example Verify email filter renders
        #   get "/admin/users"
        #   assert_admin_filter_rendered("email")
        #
        # @example Verify status filter renders
        #   get "/admin/identities"
        #   assert_admin_filter_rendered(:status)
        def assert_admin_filter_rendered(key)
          assert_select "[name*='q[#{key}]']",
                        message: "Expected filter for '#{key}'"
        end

        # Assert that breadcrumbs contain specific items.
        #
        # This method verifies that the breadcrumb navigation contains the given labels
        # in the current response body. It performs a simple text match for each label,
        # which is sufficient since breadcrumbs render their labels as plain text.
        # Useful for verifying navigation context in admin views.
        #
        # @param labels [Array<String>] one or more breadcrumb labels to look for
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if any breadcrumb label is not found
        #
        # @example Verify dashboard breadcrumb
        #   get "/admin/users"
        #   assert_admin_breadcrumbs("Dashboard")
        #
        # @example Verify full breadcrumb trail
        #   get "/admin/identities/123"
        #   assert_admin_breadcrumbs("Dashboard", "Authentication", "Identities", "#123")
        def assert_admin_breadcrumbs(*labels)
          labels.each do |label|
            assert_match label, response.body,
                         "Expected breadcrumb '#{label}' in response"
          end
        end

        # Assert that a form field exists in the response.
        #
        # This method verifies that a form field with the given key is rendered
        # in the current response. It uses `assert_select` to check for an input/select/textarea
        # element with a name attribute containing the field key in Rails form format `[key]`.
        # Useful for verifying that registered form fields appear in new/edit views.
        #
        # @param key [String, Symbol] the form field key to look for
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if the form field is not found
        #
        # @example Verify email field renders
        #   get "/admin/users/new"
        #   assert_admin_form_field("email")
        #
        # @example Verify name field renders
        #   get "/admin/users/1/edit"
        #   assert_admin_form_field(:name)
        def assert_admin_form_field(key)
          assert_select "[name*='[#{key}]']",
                        message: "Expected form field '#{key}'"
        end

        # Assert that page tabs are rendered for a static page.
        #
        # This method verifies that page action tabs with the given labels are rendered
        # in the current response body. It performs a simple text match for each label,
        # which works because page tabs render their labels as plain text within tab links.
        # Useful for verifying that registered page actions appear as tabs.
        #
        # @param labels [Array<String>] one or more page tab labels to look for
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if any page tab label is not found
        #
        # @example Verify analytics page tabs
        #   get "/admin/analytics"
        #   assert_admin_page_tabs("Overview", "By Metric")
        #
        # @example Verify settings page tabs
        #   get "/admin/settings"
        #   assert_admin_page_tabs("General", "Security", "Billing")
        def assert_admin_page_tabs(*labels)
          labels.each do |label|
            assert_match label, response.body,
                         "Expected page tab '#{label}' in response"
          end
        end

        # Assert that the current theme CSS is loaded in the layout.
        #
        # This method verifies that the stylesheet link tag for the specified theme
        # is present in the current response. It first checks that the theme is registered,
        # then uses `assert_select` to verify the CSS link tag exists with the theme's
        # CSS path in its href attribute. Useful for verifying theme application.
        #
        # @param theme_key [String, Symbol] the theme key to verify (e.g., :default, :modern)
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if the theme is not registered or CSS link is not found
        #
        # @example Verify default theme is loaded
        #   get "/admin/dashboard"
        #   assert_admin_theme(:default)
        #
        # @example Verify modern theme is loaded
        #   # After configuring: RSB::Admin.configuration.theme = :modern
        #   get "/admin/dashboard"
        #   assert_admin_theme(:modern)
        def assert_admin_theme(theme_key)
          theme = RSB::Admin.themes[theme_key.to_sym]
          assert theme, "Theme '#{theme_key}' not registered"
          assert_select "link[href*='#{theme.css}']",
                        message: "Expected theme CSS '#{theme.css}' in layout"
        end

        # Assert that a custom dashboard page is registered with the given controller.
        #
        # Verifies that `RSB::Admin.registry.dashboard_page` is present and
        # its controller matches the expected value. Useful for extension gems
        # that register a custom dashboard to verify their registration works.
        #
        # @param controller [String] the expected controller path
        #
        # @return [void]
        #
        # @raise [Minitest::Assertion] if no dashboard override or wrong controller
        #
        # @example Verify dashboard override
        #   RSB::Admin.registry.register_dashboard(controller: "admin/dashboard")
        #   assert_admin_dashboard_override(controller: "admin/dashboard")
        def assert_admin_dashboard_override(controller:)
          page = RSB::Admin.registry.dashboard_page
          assert page, 'Expected a dashboard override to be registered'
          assert_equal controller, page.controller,
                       "Expected dashboard controller '#{controller}', got '#{page.controller}'"
        end
      end
    end
  end
end
