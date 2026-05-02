# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class PlanTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        reset!
        @fired = []
        RSB::Entitlements.on(:plan_archived) { |key| @fired << key }
      end

      teardown { reset! }

      # --- Validations ---

      test 'requires key' do
        plan = Plan.new(name: 'Free')
        refute plan.valid?
        assert_includes plan.errors[:key], "can't be blank"
      end

      test 'requires name' do
        plan = Plan.new(key: 'free')
        refute plan.valid?
        assert_includes plan.errors[:name], "can't be blank"
      end

      test 'enforces unique key' do
        Plan.create!(key: 'free', name: 'Free')
        dup = Plan.new(key: 'free', name: 'Other')
        refute dup.valid?
        assert_includes dup.errors[:key], 'has already been taken'
      end

      test 'accepts arbitrary key strings (no format constraint per SRS US-002)' do
        # Plan.key has no format regex — presence/uniqueness only.
        plan = Plan.new(key: 'Pro Plan v2!', name: 'Pro')
        assert plan.valid?, plan.errors.full_messages.inspect
      end

      test 'metadata defaults to empty hash' do
        plan = Plan.create!(key: 'free', name: 'Free')
        assert_equal({}, plan.metadata)
      end

      test 'display_order defaults to 0' do
        plan = Plan.create!(key: 'free', name: 'Free')
        assert_equal 0, plan.display_order
      end

      test 'metadata stores arbitrary JSON' do
        plan = Plan.create!(key: 'pro', name: 'Pro', metadata: { 'tier' => 'paid', 'seats' => 5 })
        plan.reload
        assert_equal 'paid', plan.metadata['tier']
        assert_equal 5, plan.metadata['seats']
      end

      # --- attr_readonly :key (silent-drop on update) ---

      test 'attr_readonly drops key writes on update' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(key: 'changed')
        plan.reload
        assert_equal 'free', plan.key
      end

      test 'attr_readonly does NOT raise — Rails silently drops the write' do
        plan = Plan.create!(key: 'free', name: 'Free')
        # No exception, no validation error — just a silent no-op.
        assert_nothing_raised { plan.update!(key: 'changed') }
        plan.reload
        assert_equal 'free', plan.key
      end

      test 'allows updating non-readonly fields' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(name: 'Free Tier', display_order: 10)
        plan.reload
        assert_equal 'Free Tier', plan.name
        assert_equal 10, plan.display_order
      end

      # --- archived_record_immutable_except_unarchive ---

      test 'archived plan cannot have non-archived_at attributes updated' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)

        plan.name = 'Free 2'
        refute plan.valid?
        assert_includes plan.errors[:base].join(' '), 'archived'
      end

      test 'archived plan update! raises RecordInvalid on field change' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)

        assert_raises(ActiveRecord::RecordInvalid) do
          plan.update!(name: 'Free 2')
        end
      end

      test 'archived plan can be unarchived (archived_at: nil)' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)

        # Unarchive is the one allowed transition.
        assert_nothing_raised { plan.update!(archived_at: nil) }
        plan.reload
        assert_nil plan.archived_at
      end

      test 'unarchived plan accepts updates again after unarchive' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)
        plan.update!(archived_at: nil)
        plan.update!(name: 'Free Updated')
        plan.reload
        assert_equal 'Free Updated', plan.name
      end

      test 'archive (null -> timestamp) is allowed without other changes' do
        plan = Plan.create!(key: 'free', name: 'Free')
        assert_nothing_raised { plan.update!(archived_at: Time.current) }
      end

      # --- before_destroy hard-delete forbidden ---

      test 'destroy raises HardDeleteForbidden' do
        plan = Plan.create!(key: 'free', name: 'Free')
        assert_raises(RSB::Entitlements::HardDeleteForbidden) { plan.destroy }
        assert Plan.exists?(plan.id), 'row should still exist after blocked destroy'
      end

      test 'destroy raises HardDeleteForbidden even when archived' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)
        assert_raises(RSB::Entitlements::HardDeleteForbidden) { plan.destroy }
      end

      # --- after_commit fires :plan_archived on null -> present transition ---

      test 'archiving fires :plan_archived hook with plan key' do
        plan = Plan.create!(key: 'free', name: 'Free')
        @fired.clear

        plan.update!(archived_at: Time.current)

        assert_equal ['free'], @fired
      end

      test 'unarchiving does NOT fire :plan_archived' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)
        @fired.clear

        plan.update!(archived_at: nil)

        assert_equal [], @fired
      end

      test 'updating archived_at from one timestamp to another does NOT fire :plan_archived' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: 1.day.ago)
        @fired.clear

        # archived_at -> archived_at (different timestamp) is the only field changing — allowed.
        plan.update!(archived_at: Time.current)

        assert_equal [], @fired, 'hook fires only on null -> present transition, not present -> present'
      end

      test 'creating a plan with archived_at set does NOT fire :plan_archived' do
        # Hook semantics: fires only on null -> present *transition*, not on initial create.
        # (Matches Feature behavior; "archive event" not "born archived" event.)
        plan = Plan.create!(key: 'legacy', name: 'Legacy', archived_at: Time.current)
        assert plan.persisted?
        assert_equal [], @fired
      end

      # --- find_or_create_by! semantics ---

      test 'find_or_create_by! returns existing archived row untouched' do
        plan = Plan.create!(key: 'free', name: 'Free')
        plan.update!(archived_at: Time.current)
        archived_at_was = plan.archived_at

        found = Plan.find_or_create_by!(key: 'free') { |p| p.name = 'Free V2' }

        assert_equal plan.id, found.id
        # Block runs only on create — existing row's name and archived_at are untouched.
        assert_equal 'Free', found.name
        assert_in_delta archived_at_was.to_f, found.archived_at.to_f, 0.001
      end

      test 'find_or_create_by! creates a new plan when key does not exist' do
        plan = Plan.find_or_create_by!(key: 'pro') { |p| p.name = 'Pro' }
        assert plan.persisted?
        assert_equal 'pro', plan.key
        assert_equal 'Pro', plan.name
      end
    end
  end
end
