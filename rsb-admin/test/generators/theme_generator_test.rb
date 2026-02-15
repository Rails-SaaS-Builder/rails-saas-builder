# frozen_string_literal: true

require 'test_helper'
require 'generators/rsb/admin/theme/theme_generator'
require 'rails/generators/test_case'

class ThemeGeneratorTest < Rails::Generators::TestCase
  tests RSB::Admin::ThemeGenerator
  destination File.expand_path('../tmp', __dir__)

  setup do
    prepare_destination
    RSB::Admin.reset!
  end

  # ── Host App Scaffold (default) ──────────────────

  test 'generates CSS with all variables for host app' do
    run_generator ['corporate']

    assert_file 'app/assets/stylesheets/admin/themes/corporate.css' do |css|
      assert_match '--rsb-admin-bg:', css
      assert_match '--rsb-admin-primary:', css
      assert_match '--rsb-admin-sidebar-bg:', css
      assert_match '--rsb-admin-radius:', css
      assert_match '--rsb-admin-shadow:', css
      assert_match '--rsb-admin-transition:', css
      assert_match '--rsb-admin-text:', css
      assert_match '--rsb-admin-border:', css
      assert_match '--rsb-admin-danger:', css
      assert_match '--rsb-admin-success:', css
      assert_match '--rsb-admin-warning:', css
      assert_match '--rsb-admin-info:', css
    end
  end

  test 'generates sidebar view override for host app' do
    run_generator ['corporate']

    assert_file 'app/views/admin/themes/corporate/views/shared/_sidebar.html.erb'
  end

  test 'generates header view override for host app' do
    run_generator ['corporate']

    assert_file 'app/views/admin/themes/corporate/views/shared/_header.html.erb'
  end

  test 'generates initializer for host app' do
    run_generator ['corporate']

    assert_file 'config/initializers/rsb_admin_corporate_theme.rb' do |content|
      assert_match ':corporate', content
      assert_match '"Corporate"', content
      assert_match '"admin/themes/corporate"', content
      assert_match '"admin/themes/corporate/views"', content
    end
  end

  # ── Engine Scaffold ──────────────────────────────

  test 'generates gemspec for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/rsb-admin-corporate-theme.gemspec' do |content|
      assert_match '"rsb-admin-corporate-theme"', content
      assert_match 'add_dependency "rsb-admin"', content
    end
  end

  test 'generates engine file for engine scaffold' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/lib/rsb/admin/corporate_theme/engine.rb' do |content|
      assert_match 'CorporateTheme', content
      assert_match 'register_theme :corporate', content
      assert_match '"Corporate"', content
      assert_match '"rsb/admin/themes/corporate"', content
    end
  end

  test 'generates main lib file for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/lib/rsb/admin/corporate_theme.rb' do |content|
      assert_match 'require "rsb/admin/corporate_theme/engine"', content
    end
  end

  test 'generates CSS with all variables for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/app/assets/stylesheets/rsb/admin/themes/corporate.css' do |css|
      assert_match '--rsb-admin-bg:', css
      assert_match '--rsb-admin-primary:', css
      assert_match '--rsb-admin-sidebar-bg:', css
    end
  end

  test 'generates view overrides for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/app/views/rsb/admin/themes/corporate/views/shared/_sidebar.html.erb'
    assert_file 'rsb-admin-corporate-theme/app/views/rsb/admin/themes/corporate/views/shared/_header.html.erb'
  end

  test 'generates Gemfile for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/Gemfile' do |content|
      assert_match 'gemspec', content
    end
  end

  test 'generates Rakefile for engine' do
    run_generator ['corporate', '--engine']

    assert_file 'rsb-admin-corporate-theme/Rakefile'
  end

  # ── Naming ───────────────────────────────────────

  test 'handles hyphenated names' do
    run_generator ['dark-blue']

    assert_file 'app/assets/stylesheets/admin/themes/dark_blue.css'
    assert_file 'config/initializers/rsb_admin_dark_blue_theme.rb' do |content|
      assert_match ':dark_blue', content
    end
  end

  test 'handles hyphenated names for engine' do
    run_generator ['dark-blue', '--engine']

    assert_file 'rsb-admin-dark_blue-theme/lib/rsb/admin/dark_blue_theme/engine.rb' do |content|
      assert_match 'DarkBlueTheme', content
      assert_match ':dark_blue', content
    end
  end
end
