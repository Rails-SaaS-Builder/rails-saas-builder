# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class IdentityDeletionTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
      end

      # --- deleted status enum ---

      test 'deleted status is valid' do
        identity = RSB::Auth::Identity.create!(status: :deleted)
        assert_equal 'deleted', identity.status
      end

      test 'deleted? returns true for deleted identity' do
        identity = RSB::Auth::Identity.create!(status: :deleted)
        assert identity.deleted?
      end

      test 'deleted? returns false for active identity' do
        identity = RSB::Auth::Identity.create!(status: :active)
        assert_not identity.deleted?
      end

      # --- deleted_at column ---

      test 'deleted_at can be set and persists' do
        freeze_time do
          identity = RSB::Auth::Identity.create!(status: :deleted, deleted_at: Time.current)
          assert_equal Time.current, identity.reload.deleted_at
        end
      end

      test 'deleted_at is nil by default' do
        identity = RSB::Auth::Identity.create!
        assert_nil identity.deleted_at
      end

      # --- scopes ---

      test 'deleted scope returns only deleted identities' do
        active = RSB::Auth::Identity.create!(status: :active)
        deleted = RSB::Auth::Identity.create!(status: :deleted, deleted_at: Time.current)

        result = RSB::Auth::Identity.deleted
        assert_includes result, deleted
        assert_not_includes result, active
      end

      test 'active scope excludes deleted identities' do
        active = RSB::Auth::Identity.create!(status: :active)
        deleted = RSB::Auth::Identity.create!(status: :deleted, deleted_at: Time.current)
        suspended = RSB::Auth::Identity.create!(status: :suspended)

        result = RSB::Auth::Identity.active
        assert_includes result, active
        assert_not_includes result, deleted
        assert_not_includes result, suspended
      end
    end
  end
end
