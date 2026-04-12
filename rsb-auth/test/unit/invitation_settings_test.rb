# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationSettingsTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
      end

      test 'invitation_expiry_hours is registered with default 168' do
        value = RSB::Settings.get('auth.invitation_expiry_hours')
        assert_equal 168, value
      end

      test 'invitation_default_max_uses is registered with default 1' do
        value = RSB::Settings.get('auth.invitation_default_max_uses')
        assert_equal 1, value
      end

      test 'invitation_expiry_hours is integer type' do
        schema = RSB::Settings.registry.for('auth').find('invitation_expiry_hours')
        assert_equal :integer, schema.type
      end

      test 'invitation_default_max_uses is integer type' do
        schema = RSB::Settings.registry.for('auth').find('invitation_default_max_uses')
        assert_equal :integer, schema.type
      end
    end
  end
end
