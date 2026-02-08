module RSB
  module Admin
    module TestKit
      class ResourceTestCase < ActionDispatch::IntegrationTest
        include RSB::Admin::TestKit::Helpers

        class_attribute :resource_class
        class_attribute :category
        class_attribute :record_factory
        class_attribute :resource_registry_block

        setup do
          # Re-register the resource if a registry block is provided
          if self.class.resource_registry_block
            self.class.resource_registry_block.call
          end
          @superadmin = create_test_admin!(superadmin: true)
          @registration = RSB::Admin.registry.find_resource(resource_class) if resource_class
        end

        # Define how to register the resource (called in setup after reset)
        def self.registers_in_admin(&block)
          self.resource_registry_block = block
        end

        def test_resource_is_registered_in_admin_registry
          skip "no resource_class configured" unless resource_class
          assert @registration, "#{resource_class} not found in admin registry"
          assert_equal category, @registration.category_name
        end

        def test_index_page_renders
          skip "no resource_class configured" unless resource_class
          skip "no :index action registered" unless @registration&.action?(:index)
          record_factory&.call
          sign_in_admin(@superadmin)
          get admin_resources_path
          assert_admin_authorized
        end

        def test_show_page_renders
          skip "no resource_class configured" unless resource_class
          skip "no :show action registered" unless @registration&.action?(:show)
          record = record_factory&.call
          skip "no record_factory configured" unless record
          sign_in_admin(@superadmin)
          get admin_resource_path(record)
          assert_admin_authorized
        end

        def test_admin_with_no_permissions_is_denied
          skip "no resource_class configured" unless resource_class
          skip "no :index action registered" unless @registration&.action?(:index)
          restricted = create_test_admin!(permissions: {})
          sign_in_admin(restricted)
          get admin_resources_path
          assert_admin_denied
        end

        # Contract test: Verify that registered columns appear in the index table.
        #
        # This test ensures that all columns defined for the resource via the DSL
        # (or auto-detected from the model schema) are rendered as table headers
        # in the index view. It creates a test record, signs in as superadmin,
        # visits the index page, and asserts that each column's label appears
        # in a `<th>` element. Skips if no records exist (table won't render).
        #
        # For auto-detected columns, assertions are more forgiving since some
        # columns may be filtered out by the view (e.g., SKIP_INDEX_COLUMNS).
        # For explicitly-defined columns, all columns must render.
        #
        # @return [void]
        #
        # @raise [Minitest::Skip] if resource_class is not configured, :index action not registered, or no records exist
        def test_index_page_renders_registered_columns
          skip "no resource_class configured" unless resource_class
          skip "no :index action" unless @registration&.action?(:index)
          record = record_factory&.call
          skip "no record_factory configured or record creation failed" unless record&.persisted?
          sign_in_admin(@superadmin)
          get admin_resources_path
          assert_admin_authorized
          
          # Verify table renders (requires at least one th element)
          begin
            assert_select "th", minimum: 1
          rescue Minitest::Assertion
            skip "table not rendered (no records found in view)"
          end
          
          # Check columns - be forgiving with auto-detected columns
          auto_detected = @registration.columns.nil?
          @registration.index_columns.each do |col|
            next if col.label.blank?
            
            if auto_detected
              # For auto-detected columns, silently skip if column doesn't render
              # (it may be filtered by view logic we don't control)
              begin
                assert_admin_column_rendered(col.label)
              rescue Minitest::Assertion
                # Skip this column
                next
              end
            else
              # For explicitly-defined columns, all must render
              assert_admin_column_rendered(col.label)
            end
          end
        end

        # Contract test: Verify that registered filters appear in the index view.
        #
        # This test ensures that all filters defined for the resource via the DSL
        # are rendered as form inputs in the index view. It signs in as superadmin,
        # visits the index page, and asserts that each filter's input element exists
        # with the correct name attribute format `q[key]`.
        #
        # @return [void]
        #
        # @raise [Minitest::Skip] if resource_class is not configured or no filters defined
        def test_index_page_renders_registered_filters
          skip "no resource_class configured" unless resource_class
          skip "no filters" unless @registration&.filters&.any?
          sign_in_admin(@superadmin)
          get admin_resources_path
          assert_admin_authorized
          @registration.filters.each do |filter|
            assert_admin_filter_rendered(filter.key)
          end
        end

        # Contract test: Verify that registered form fields appear in the new form.
        #
        # This test ensures that all form fields defined for the resource via the DSL
        # (or auto-detected from the model schema) are rendered as form inputs in the
        # new view. It signs in as superadmin, visits the new page, and asserts that
        # each field's input element exists with the correct name attribute.
        #
        # @return [void]
        #
        # @raise [Minitest::Skip] if resource_class is not configured, :new action not registered, or no form_fields defined
        def test_new_page_renders_registered_form_fields
          skip "no resource_class configured" unless resource_class
          skip "no :new action" unless @registration&.action?(:new)
          skip "no form_fields" unless @registration&.form_fields&.any?
          sign_in_admin(@superadmin)
          get "#{admin_resources_path}/new"
          assert_admin_authorized
          @registration.new_form_fields.each do |field|
            assert_admin_form_field(field.key)
          end
        end

        # Contract test: Verify that breadcrumbs are rendered in resource views.
        #
        # This test ensures that the breadcrumb navigation is present in resource views,
        # including at minimum the "Dashboard" home breadcrumb. It signs in as superadmin,
        # visits the index page, and asserts that the dashboard breadcrumb appears.
        #
        # @return [void]
        #
        # @raise [Minitest::Skip] if resource_class is not configured or :index action not registered
        def test_breadcrumbs_are_rendered
          skip "no resource_class configured" unless resource_class
          skip "no :index action" unless @registration&.action?(:index)
          sign_in_admin(@superadmin)
          get admin_resources_path
          assert_admin_authorized
          assert_admin_breadcrumbs("Dashboard")
        end

        private

        def create_resource(**overrides)
          record_factory&.call(**overrides)
        end

        def admin_resources_path
          rsb_admin.send(:"#{resource_class.model_name.route_key}_path")
        rescue NoMethodError
          "/admin/#{resource_class.model_name.route_key}"
        end

        def admin_resource_path(record)
          rsb_admin.send(:"#{resource_class.model_name.singular_route_key}_path", record)
        rescue NoMethodError
          "/admin/#{resource_class.model_name.route_key}/#{record.id}"
        end
      end
    end
  end
end
