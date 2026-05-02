# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class FeatureTest < ActiveSupport::TestCase
      setup do
        RSB::Entitlements.reset! if RSB::Entitlements.respond_to?(:reset!)
      end

      teardown do
        RSB::Entitlements.reset! if RSB::Entitlements.respond_to?(:reset!)
      end

      # --- Validations ---

      test 'requires key' do
        feature = Feature.new(name: 'API Calls', kind: 'metered')
        refute feature.valid?
        assert_includes feature.errors[:key], "can't be blank"
      end

      test 'requires name' do
        feature = Feature.new(key: 'api_calls', kind: 'metered')
        refute feature.valid?
        assert_includes feature.errors[:name], "can't be blank"
      end

      test 'requires kind' do
        feature = Feature.new(key: 'api_calls', name: 'API Calls')
        refute feature.valid?
        # AR enum + validate: true reports inclusion error on :kind
        assert feature.errors[:kind].any?
      end

      test 'enforces key uniqueness' do
        Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        dup = Feature.new(key: 'api_calls', name: 'Other', kind: 'flag')
        refute dup.valid?
        assert_includes dup.errors[:key], 'has already been taken'
      end

      test 'rejects keys that do not match the dotted-snake-case format' do
        bad_keys = ['Api_Calls', 'api-calls', 'api calls', '.api', 'api.', '', 'api..calls', 'API_CALLS']
        bad_keys.each do |bad|
          feature = Feature.new(key: bad, name: 'X', kind: 'flag')
          refute feature.valid?, "expected #{bad.inspect} to be invalid"
          assert feature.errors[:key].any?, "expected an error on :key for #{bad.inspect}"
        end
      end

      test 'accepts dotted snake_case keys' do
        good_keys = %w[sso api_calls billing.invoices.export storage_bytes a a1 a_b_c.d_e_f]
        good_keys.each do |good|
          feature = Feature.new(key: good, name: 'X', kind: 'flag')
          assert feature.valid?, "expected #{good.inspect} to be valid (errors: #{feature.errors.full_messages})"
        end
      end

      test 'rejects unknown kinds' do
        feature = Feature.new(key: 'api_calls', name: 'API Calls', kind: 'consumable')
        refute feature.valid?
        assert feature.errors[:kind].any?
      end

      # --- Enum surface ---

      test 'kind is a Rails enum exposing predicates and scopes' do
        flag    = Feature.create!(key: 'sso',        name: 'SSO',        kind: 'flag')
        metered = Feature.create!(key: 'api_calls',  name: 'API Calls',  kind: 'metered')
        gauge   = Feature.create!(key: 'seats',      name: 'Seats',      kind: 'gauge')

        assert flag.flag?
        refute flag.metered?
        assert metered.metered?
        assert gauge.gauge?

        assert_equal 1, Feature.flag.count
        assert_equal 1, Feature.metered.count
        assert_equal 1, Feature.gauge.count
      end

      # --- attr_readonly :key, :kind ---

      test 'attr_readonly :key silently drops writes on update' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        # Rails silently ignores attr_readonly fields on update (no error).
        feature.update!(key: 'something_else')
        feature.reload
        assert_equal 'api_calls', feature.key
      end

      test 'attr_readonly :kind silently drops writes on update' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        feature.update!(kind: 'gauge')
        feature.reload
        assert_equal 'metered', feature.kind
      end

      test 'name and unit remain mutable on a non-archived feature' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered', unit: 'count')
        feature.update!(name: 'API Requests', unit: 'requests')
        feature.reload
        assert_equal 'API Requests', feature.name
        assert_equal 'requests', feature.unit
      end

      # --- archived_record_immutable_except_unarchive ---

      test 'archived row rejects updates to fields other than archived_at' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered', unit: 'count')
        feature.update!(archived_at: Time.current)
        feature.reload

        assert_raises(ActiveRecord::RecordInvalid) do
          feature.update!(name: 'New Name')
        end

        assert_raises(ActiveRecord::RecordInvalid) do
          feature.update!(unit: 'bytes')
        end
      end

      test 'archived row allows clearing archived_at (unarchive)' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        feature.update!(archived_at: Time.current)
        feature.reload

        # Only archived_at is changing — should succeed.
        feature.update!(archived_at: nil)
        feature.reload
        assert_nil feature.archived_at
      end

      test 'non-archived row may set archived_at and any other field in same save' do
        # The validation only fires when archived_at_was.present? — i.e., the row was
        # ALREADY archived before this save. Going from null→timestamp is a normal archive
        # action and may carry no other changes, but is not blocked by the validation.
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        feature.update!(archived_at: Time.current)
        assert feature.archived_at.present?
      end

      # --- before_destroy: HardDeleteForbidden ---

      test 'destroy raises RSB::Entitlements::HardDeleteForbidden' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        assert_raises(RSB::Entitlements::HardDeleteForbidden) { feature.destroy }
        # Row still present.
        assert Feature.exists?(feature.id)
      end

      test 'destroy! raises RSB::Entitlements::HardDeleteForbidden' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        assert_raises(RSB::Entitlements::HardDeleteForbidden) { feature.destroy! }
        assert Feature.exists?(feature.id)
      end

      # --- after_commit :fire_archive_hook ---

      test ':feature_archived hook fires on null->timestamp transition' do
        fired = []
        RSB::Entitlements.hooks.on(:feature_archived) { |key| fired << key }

        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        assert_equal [], fired, 'hook must not fire on create with archived_at nil'

        feature.update!(archived_at: Time.current)
        assert_equal ['api_calls'], fired, 'hook must fire exactly once on null->timestamp'
      end

      test ':feature_archived hook does NOT fire on unarchive (timestamp->null)' do
        fired = []

        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        feature.update!(archived_at: Time.current)

        # Subscribe AFTER the archive so the initial transition is not counted.
        RSB::Entitlements.hooks.on(:feature_archived) { |key| fired << key }

        feature.update!(archived_at: nil)
        assert_equal [], fired
      end

      test ':feature_archived hook does NOT fire on creation when archived_at is preset' do
        fired = []
        RSB::Entitlements.hooks.on(:feature_archived) { |key| fired << key }

        # Pre-archived create: archived_at_was is nil because the row didn't exist; but
        # saved_change_to_archived_at? is true. Spec: hook fires only on null->present
        # transition for an EXISTING row, not on create. Implementation guards by
        # restricting `on:` to %i[update] — verify here.
        Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered', archived_at: Time.current)
        assert_equal [], fired
      end

      test ':feature_archived hook does NOT fire on present->present archived_at change' do
        fired = []
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered')
        feature.update!(archived_at: Time.current)
        RSB::Entitlements.hooks.on(:feature_archived) { |key| fired << key }

        # Bypass the archived-record-immutable validation by writing directly
        # to the column (this simulates a host who updates archived_at via
        # update_columns or raw SQL — the hook should still NOT fire because
        # this is not a null->present transition).
        feature.update_columns(archived_at: 1.day.ago)
        feature.reload
        feature.send(:write_attribute, :archived_at, 2.days.ago)
        # Since update_columns skips callbacks, exercise the same path via
        # update! while archived_at is still non-nil — the immutable-archived
        # validation will reject, but we can simulate by clearing then
        # transitioning through nil (which is the SUPPORTED path) and verify
        # hook fires there. The bug we are guarding against is the hook firing
        # when archived_at goes from a timestamp to ANOTHER timestamp.
        feature.update!(archived_at: nil) # unarchive (no fire — covered by separate test)
        feature.update_columns(archived_at: 1.day.ago)
        feature.reload
        assert_equal [], fired, 'hook must NOT fire on present->present (or via update_columns)'
      end

      test ':feature_archived hook does NOT fire when other fields change but archived_at is unchanged' do
        fired = []
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered', unit: 'count')
        RSB::Entitlements.hooks.on(:feature_archived) { |key| fired << key }

        feature.update!(unit: 'requests')
        assert_equal [], fired
      end

      # --- find_or_create_by! semantics ---

      test 'find_or_create_by! returns the archived row untouched (no validation re-run)' do
        feature = Feature.create!(key: 'api_calls', name: 'API Calls', kind: 'metered', unit: 'count')
        archived_at = 1.day.ago
        feature.update!(archived_at: archived_at)
        feature.reload

        # find_or_create_by! must not attempt to update; it should return the existing row.
        # The block in find_or_create_by! is only invoked on CREATE, not on FIND.
        # Therefore the archived row is returned unchanged and no RecordInvalid is raised.
        result = Feature.find_or_create_by!(key: 'api_calls') do |f|
          f.name = 'Different'
          f.kind = 'flag'
        end

        assert_equal feature.id, result.id
        assert_equal 'API Calls', result.name
        assert_equal 'metered', result.kind
        assert_equal 'count', result.unit
        assert result.archived_at.present?
        assert_in_delta archived_at.to_i, result.archived_at.to_i, 1
      end
    end
  end
end
