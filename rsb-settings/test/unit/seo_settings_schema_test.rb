# frozen_string_literal: true

require 'test_helper'

class SeoSettingsSchemaTest < ActiveSupport::TestCase
  setup do
    RSB::Settings.reset!
    @schema = RSB::Settings::SeoSettingsSchema.build
    RSB::Settings.registry.register(@schema)
  end

  teardown do
    RSB::Settings.reset!
  end

  test 'seo category is registered' do
    assert_includes RSB::Settings.registry.categories, 'seo'
  end

  test 'seo.app_name defaults to empty string' do
    assert_equal '', RSB::Settings.get('seo.app_name')
  end

  test 'seo.title_format has default pattern' do
    assert_equal '%<page_title>s | %<app_name>s', RSB::Settings.get('seo.title_format')
  end

  test 'seo.og_image_url defaults to empty string' do
    assert_equal '', RSB::Settings.get('seo.og_image_url')
  end

  test 'seo.auth_indexable defaults to true' do
    assert_equal true, RSB::Settings.get('seo.auth_indexable')
  end

  test 'seo.head_tags defaults to empty string' do
    assert_equal '', RSB::Settings.get('seo.head_tags')
  end

  test 'seo.body_tags defaults to empty string' do
    assert_equal '', RSB::Settings.get('seo.body_tags')
  end

  test 'seo settings are editable' do
    RSB::Settings.set('seo.app_name', 'My App')
    assert_equal 'My App', RSB::Settings.get('seo.app_name')
  end

  test 'schema has correct groups' do
    groups = RSB::Settings.registry.grouped_definitions('seo').keys
    assert_includes groups, 'General'
    assert_includes groups, 'Open Graph'
    assert_includes groups, 'Robots'
    assert_includes groups, 'Script Injection'
  end
end
