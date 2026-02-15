# frozen_string_literal: true

require 'test_helper'
require 'rsb/admin/test_kit'

class TestKitHelpersExpansionTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    RSB::Admin.registry.register_category 'Content' do
      resource TestPost,
               actions: %i[index show new create edit update destroy] do
        column :id, link: true
        column :title, sortable: true
        column :status, formatter: :badge
        filter :status, type: :text
        form_field :title, type: :text, required: true
        form_field :body, type: :textarea
      end
    end

    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  test 'assert_admin_column_rendered finds column header' do
    # Create a record so the table renders
    TestPost.create!(title: 'Test Post', body: 'Content', status: 'published')

    get '/admin/test_posts'
    assert_admin_authorized
    assert_admin_column_rendered('Title')
  end

  test 'assert_admin_filter_rendered finds filter input' do
    get '/admin/test_posts'
    assert_admin_authorized
    assert_admin_filter_rendered('status')
  end

  test 'assert_admin_breadcrumbs finds breadcrumb labels' do
    get '/admin/test_posts'
    assert_admin_authorized
    assert_admin_breadcrumbs('Dashboard', 'Content')
  end

  test 'assert_admin_form_field finds form field' do
    get '/admin/test_posts/new'
    assert_admin_authorized
    assert_admin_form_field('title')
  end

  test 'assert_admin_theme finds theme CSS link' do
    get rsb_admin.dashboard_path
    assert_admin_theme(:default)
  end

  test 'assert_admin_page_tabs finds page tab labels' do
    # Test the helper by visiting settings page which has the System category tabs
    # The tabs render as links with the action labels
    get rsb_admin.settings_path
    # Settings page renders with "Settings" as the title which acts as a tab
    assert_admin_page_tabs('Settings')
  end

  test 'assert_admin_dashboard_override passes when dashboard registered with matching controller' do
    RSB::Admin.registry.register_dashboard(controller: 'admin/custom_dashboard')
    assert_admin_dashboard_override(controller: 'admin/custom_dashboard')
  end

  test 'assert_admin_dashboard_override fails when no dashboard registered' do
    assert_raises(Minitest::Assertion) { assert_admin_dashboard_override(controller: 'admin/foo') }
  end

  test "assert_admin_dashboard_override fails when controller doesn't match" do
    RSB::Admin.registry.register_dashboard(controller: 'admin/other')
    assert_raises(Minitest::Assertion) { assert_admin_dashboard_override(controller: 'admin/foo') }
  end
end

class ResourceTestCaseContractTest < RSB::Admin::TestKit::ResourceTestCase
  self.resource_class = TestPost
  self.category = 'Content'
  self.record_factory = lambda {
    TestPost.create!(
      title: "Contract Test Post #{SecureRandom.hex(4)}",
      body: 'Test content',
      status: 'published'
    )
  }

  registers_in_admin do
    RSB::Admin.registry.register_category 'Content' do
      resource TestPost,
               actions: %i[index show new create] do
        column :id, link: true
        column :title, sortable: true
        column :status, formatter: :badge
        filter :status, type: :text
        form_field :title, type: :text, required: true
        form_field :body, type: :textarea
      end
    end
  end

  # Inherits all contract tests:
  # - test_resource_is_registered_in_admin_registry
  # - test_index_page_renders
  # - test_show_page_renders
  # - test_admin_with_no_permissions_is_denied
  # NEW:
  # - test_index_page_renders_registered_columns
  # - test_index_page_renders_registered_filters
  # - test_new_page_renders_registered_form_fields
  # - test_breadcrumbs_are_rendered
end
