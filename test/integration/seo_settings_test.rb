# frozen_string_literal: true

require 'test_helper'

class SeoSettingsTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
    register_all_settings
  end

  teardown do
    RSB::Settings.reset!
  end

  test 'seo category is registered alongside auth and admin' do
    categories = RSB::Settings.registry.categories
    assert_includes categories, 'seo'
    assert_includes categories, 'auth'
    assert_includes categories, 'admin'
  end

  test 'seo settings are accessible via RSB::Settings.get' do
    assert_equal '', RSB::Settings.get('seo.app_name')
    assert_equal true, RSB::Settings.get('seo.auth_indexable')
    assert_equal '%<page_title>s | %<app_name>s', RSB::Settings.get('seo.title_format')
  end

  test 'seo settings are writable' do
    RSB::Settings.set('seo.app_name', 'Cross-Gem Test')
    assert_equal 'Cross-Gem Test', RSB::Settings.get('seo.app_name')
  end

  test 'seo settings have expected groups' do
    groups = RSB::Settings.registry.grouped_definitions('seo').keys
    assert_includes groups, 'General'
    assert_includes groups, 'Script Injection'
  end

  test 'seo settings do not conflict with other category settings' do
    # Verify no key collisions
    assert_nothing_raised { RSB::Settings.get('seo.app_name') }
    assert_nothing_raised { RSB::Settings.get('admin.app_name') }
    assert_not_equal RSB::Settings.get('seo.app_name'), RSB::Settings.get('admin.app_name')
  end
end
