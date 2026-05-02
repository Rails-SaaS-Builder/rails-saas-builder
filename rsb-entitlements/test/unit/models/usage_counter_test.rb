# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class UsageCounterTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      setup do
        @feature = Feature.create!(key: 'api_calls', kind: 'metered',
                                   name: 'API', unit: 'count')
        @org = Organization.create!(name: 'Acme')
      end

      def base(**overrides)
        {
          subject_type: @org.class.name,
          subject_id: @org.id,
          feature_key: 'api_calls',
          period_start: Time.current.beginning_of_month,
          consumed: 0
        }.merge(overrides)
      end

      # --- Associations ---

      test 'belongs_to :feature via (feature_key → features.key)' do
        counter = UsageCounter.create!(base)
        assert_equal @feature, counter.feature
      end

      # --- Validations ---

      test 'requires subject_type, subject_id, feature_key' do
        c = UsageCounter.new
        refute c.valid?
        %i[subject_type subject_id feature_key].each do |attr|
          assert c.errors[attr].any?, "expected validation error on #{attr}"
        end
      end

      # --- Uniqueness (DB layer) ---

      test '(subject_type, subject_id, feature_key) is unique at the DB layer' do
        UsageCounter.create!(base)
        assert_raises(ActiveRecord::RecordNotUnique) do
          # Bypass Rails-side uniqueness so we exercise the unique index directly.
          UsageCounter.new(base.merge(consumed: 5)).save!(validate: false)
        end
      end

      # --- CHECK constraint: consumed >= 0 ---

      test 'CHECK constraint rejects consumed < 0 (PG check_violation)' do
        # Use raw SQL with bypass-validation semantics to ensure the DB raises,
        # not the AR numericality validator. Wrap in requires_new: true so that
        # on PG the CHECK violation only aborts the savepoint, not the outer
        # Minitest transaction (which teardown still needs to clean up).
        assert_raises(ActiveRecord::StatementInvalid) do
          UsageCounter.connection.transaction(requires_new: true) do
            UsageCounter.connection.execute(<<~SQL.squish)
              INSERT INTO rsb_entitlements_usage_counters
                (subject_type, subject_id, feature_key, period_start, consumed, updated_at)
              VALUES
                ('#{@org.class.name}', #{@org.id}, 'api_calls', now(), -1, now())
            SQL
          end
        end
      end

      # --- lock_or_init ---

      test 'lock_or_init inserts a row with consumed=0 when missing' do
        period = Time.current.beginning_of_month
        ActiveRecord::Base.transaction do
          counter = UsageCounter.lock_or_init(
            subject_type: @org.class.name, subject_id: @org.id,
            feature_key: 'api_calls', default_period_start: period
          )
          assert_predicate counter, :persisted?
          assert_equal 0, counter.consumed
          assert_in_delta period.to_f, counter.period_start.to_f, 1.0
        end
        assert_equal 1, UsageCounter.where(subject_id: @org.id, feature_key: 'api_calls').count
      end

      test 'lock_or_init returns the existing row when present' do
        existing = UsageCounter.create!(base.merge(consumed: 10))
        ActiveRecord::Base.transaction do
          counter = UsageCounter.lock_or_init(
            subject_type: @org.class.name, subject_id: @org.id,
            feature_key: 'api_calls',
            default_period_start: Time.current.beginning_of_month
          )
          assert_equal existing.id, counter.id
          assert_equal 10, counter.consumed
        end
      end

      test 'lock_or_init does not overwrite the existing period_start' do
        old_start = 2.months.ago
        UsageCounter.create!(base.merge(period_start: old_start, consumed: 3))
        ActiveRecord::Base.transaction do
          counter = UsageCounter.lock_or_init(
            subject_type: @org.class.name, subject_id: @org.id,
            feature_key: 'api_calls',
            default_period_start: Time.current.beginning_of_month
          )
          assert_in_delta old_start.to_f, counter.period_start.to_f, 1.0
          assert_equal 3, counter.consumed
        end
      end

      test 'lock_or_init returns a row that is locked FOR UPDATE' do
        skip 'requires PostgreSQL row-level locking' unless postgres?

        # First caller creates and locks the row inside an open transaction.
        UsageCounter.create!(base.merge(consumed: 1))

        gate = Queue.new # signals the second thread to start
        second_locked_at = nil
        first_committed_at = nil

        thread = Thread.new do
          # Wait until the main thread has acquired the lock and signaled.
          gate.pop

          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              UsageCounter.lock_or_init(
                subject_type: @org.class.name, subject_id: @org.id,
                feature_key: 'api_calls',
                default_period_start: Time.current.beginning_of_month
              )
              second_locked_at = Time.current
            end
          end
        end

        ActiveRecord::Base.transaction do
          UsageCounter.lock_or_init(
            subject_type: @org.class.name, subject_id: @org.id,
            feature_key: 'api_calls',
            default_period_start: Time.current.beginning_of_month
          )
          gate << :go
          # Hold the lock briefly to give the second thread a chance to block.
          sleep 0.3
          first_committed_at = Time.current
        end

        thread.join(5) || flunk('second thread did not finish — likely deadlock')
        assert second_locked_at >= first_committed_at,
               'second caller acquired its lock before the first transaction committed'
      end

      test 'lock_or_init is idempotent under concurrent first-create race' do
        skip 'requires PostgreSQL ON CONFLICT DO NOTHING' unless postgres?

        # Race two threads both creating the same (subject, feature) counter.
        threads = 2.times.map do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              ActiveRecord::Base.transaction do
                UsageCounter.lock_or_init(
                  subject_type: @org.class.name, subject_id: @org.id,
                  feature_key: 'api_calls',
                  default_period_start: Time.current.beginning_of_month
                )
              end
            end
          end
        end
        threads.each(&:join)

        # Exactly one row should exist, no exceptions raised.
        assert_equal 1, UsageCounter.where(
          subject_type: @org.class.name, subject_id: @org.id,
          feature_key: 'api_calls'
        ).count
      end

      private

      def postgres?
        ActiveRecord::Base.connection.adapter_name =~ /postgres/i
      end
    end
  end
end
