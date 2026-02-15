# frozen_string_literal: true

require 'test_helper'
require 'generators/rsb/admin/views/views_generator'
require 'rails/generators/test_case'

class ViewsGeneratorTest < Rails::Generators::TestCase
  tests RSB::Admin::ViewsGenerator
  destination File.expand_path('../tmp', __dir__)

  setup do
    prepare_destination
    RSB::Admin.reset!
  end

  test 'generator exports all default views when no options given' do
    run_generator

    # Spot-check key files
    assert_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'
    assert_file 'app/views/rsb_admin_overrides/shared/_header.html.erb'
    assert_file 'app/views/rsb_admin_overrides/shared/_breadcrumbs.html.erb'
    assert_file 'app/views/rsb_admin_overrides/resources/index.html.erb'
    assert_file 'app/views/rsb_admin_overrides/resources/show.html.erb'
    assert_file 'app/views/rsb_admin_overrides/dashboard/index.html.erb'
    assert_file 'app/views/rsb_admin_overrides/sessions/new.html.erb'
  end

  test 'generator exports only specified groups with --only' do
    run_generator ['--only', 'sidebar,header']

    assert_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'
    assert_file 'app/views/rsb_admin_overrides/shared/_header.html.erb'
    assert_no_file 'app/views/rsb_admin_overrides/resources/index.html.erb'
    assert_no_file 'app/views/rsb_admin_overrides/dashboard/index.html.erb'
  end

  test 'generator exports only layout group' do
    run_generator ['--only', 'layout']

    assert_file 'app/views/rsb_admin_overrides/layouts/rsb/admin/application.html.erb'
    assert_no_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'
  end

  test 'generator exports fields group' do
    run_generator ['--only', 'fields']

    assert_file 'app/views/rsb_admin_overrides/shared/fields/_text.html.erb'
    assert_file 'app/views/rsb_admin_overrides/shared/fields/_select.html.erb'
    assert_file 'app/views/rsb_admin_overrides/shared/fields/_checkbox.html.erb'
    assert_no_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'
  end

  test 'generator skips existing files without --force' do
    run_generator ['--only', 'sidebar']
    # File exists from first run
    assert_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'

    # Run again — should skip
    output = run_generator ['--only', 'sidebar']
    assert_match(/skip/, output)
  end

  test 'generator overwrites existing files with --force' do
    run_generator ['--only', 'sidebar']
    # Modify the file
    File.write(
      File.join(destination_root, 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'),
      'modified content'
    )

    run_generator ['--only', 'sidebar', '--force']

    content = File.read(File.join(destination_root, 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb'))
    refute_equal 'modified content', content
  end

  test 'generator creates initializer when view_overrides_path is nil' do
    RSB::Admin.configuration.view_overrides_path = nil
    run_generator ['--only', 'sidebar']

    assert_file 'config/initializers/rsb_admin_views.rb' do |content|
      assert_match 'config.view_overrides_path = "rsb_admin_overrides"', content
    end
  end

  test 'generator does not create initializer when view_overrides_path is already set' do
    RSB::Admin.configuration.view_overrides_path = 'my_custom_path'
    run_generator ['--only', 'sidebar']

    assert_no_file 'config/initializers/rsb_admin_views.rb'
    assert_file 'app/views/my_custom_path/shared/_sidebar.html.erb'
  end

  test 'generator uses theme views when --theme is specified' do
    run_generator ['--only', 'sidebar', '--theme', 'modern']

    assert_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb' do |content|
      # Modern sidebar has the collapsible sections with rsbToggleSection
      assert_match 'rsbToggleSection', content
    end
  end

  test 'generator uses default views when --theme specifies theme without views_path' do
    run_generator ['--only', 'sidebar', '--theme', 'default']

    assert_file 'app/views/rsb_admin_overrides/shared/_sidebar.html.erb' do |content|
      # Default sidebar does NOT have rsbToggleSection
      refute_match 'rsbToggleSection', content
    end
  end

  test 'generator produces error for invalid --only group names' do
    # Generator calls exit(1) for invalid groups, so we need to catch the SystemExit
    assert_raises(SystemExit) do
      run_generator ['--only', 'invalid_group']
    end
  end

  test 'generator produces error for invalid --theme name' do
    # Generator calls exit(1) for invalid theme, so we need to catch the SystemExit
    assert_raises(SystemExit) do
      run_generator ['--theme', 'nonexistent']
    end
  end
end
