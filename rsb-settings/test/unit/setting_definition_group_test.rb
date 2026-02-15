# frozen_string_literal: true

require 'test_helper'

class SettingDefinitionGroupTest < ActiveSupport::TestCase
  test 'SettingDefinition accepts group and depends_on' do
    defn = RSB::Settings::Schema::SettingDefinition.new(
      key: :session_duration,
      type: :integer,
      default: 86_400,
      description: 'Session TTL',
      enum: nil,
      validates: nil,
      encrypted: false,
      locked: false,
      group: 'Session & Security',
      depends_on: 'auth.enabled'
    )

    assert_equal 'Session & Security', defn.group
    assert_equal 'auth.enabled', defn.depends_on
  end

  test 'SettingDefinition defaults group and depends_on to nil' do
    defn = RSB::Settings::Schema::SettingDefinition.new(
      key: :name,
      type: :string,
      default: '',
      description: 'Name',
      enum: nil,
      validates: nil,
      encrypted: false,
      locked: false
    )

    assert_nil defn.group
    assert_nil defn.depends_on
  end

  test 'Schema#setting accepts group: and depends_on: keyword args' do
    schema = RSB::Settings::Schema.new('test') do
      setting :master_toggle,
              type: :boolean,
              default: true,
              group: 'Features',
              description: 'Master toggle'

      setting :sub_feature,
              type: :boolean,
              default: true,
              group: 'Features',
              depends_on: 'test.master_toggle',
              description: 'Sub feature'
    end

    master = schema.find(:master_toggle)
    assert_equal 'Features', master.group
    assert_nil master.depends_on

    sub = schema.find(:sub_feature)
    assert_equal 'Features', sub.group
    assert_equal 'test.master_toggle', sub.depends_on
  end

  test 'Schema#setting works without group and depends_on (backward compat)' do
    schema = RSB::Settings::Schema.new('legacy') do
      setting :old_setting,
              type: :string,
              default: 'val',
              description: 'Old setting'
    end

    defn = schema.find(:old_setting)
    assert_nil defn.group
    assert_nil defn.depends_on
  end
end
