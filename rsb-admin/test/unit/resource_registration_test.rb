# frozen_string_literal: true

require 'test_helper'

class ResourceRegistrationTest < ActiveSupport::TestCase
  test 'initializes with all attributes' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::Role,
      category_name: 'System',
      icon: 'shield',
      label: 'Roles',
      actions: %i[index show edit]
    )

    assert_equal RSB::Admin::Role, reg.model_class
    assert_equal 'System', reg.category_name
    assert_equal 'shield', reg.icon
    assert_equal 'Roles', reg.label
    assert_equal %i[index show edit], reg.actions
  end

  test 'action? returns true for registered actions' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::Role,
      category_name: 'System',
      actions: %i[index show]
    )

    assert reg.action?(:index)
    assert reg.action?(:show)
    refute reg.action?(:edit)
    refute reg.action?(:destroy)
  end

  test 'action? works with string argument' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::Role,
      category_name: 'System',
      actions: [:index]
    )

    # action? converts to symbol
    assert reg.action?(:index)
  end

  test 'stores extra options' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::Role,
      category_name: 'System',
      actions: [:index],
      custom_option: true,
      metadata: { foo: 'bar' }
    )

    assert_equal({ custom_option: true, metadata: { foo: 'bar' } }, reg.options)
  end

  test 'defaults icon to nil and label to humanized model name' do
    reg = RSB::Admin::ResourceRegistration.new(
      model_class: RSB::Admin::Role,
      category_name: 'System'
    )

    assert_nil reg.icon
    assert_includes reg.label, 'Role'
    assert_equal [], reg.actions
  end

  test 'SENSITIVE_COLUMNS contains expected column names' do
    sensitive = RSB::Admin::ResourceRegistration::SENSITIVE_COLUMNS
    assert_includes sensitive, 'password_digest'
    assert_includes sensitive, 'token'
    assert_includes sensitive, 'encrypted_password'
  end
end
