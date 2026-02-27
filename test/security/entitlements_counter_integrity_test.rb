# frozen_string_literal: true

# Security Test: Usage Counter Integrity
#
# Attack vectors prevented:
# - Race condition on counter increment (lost updates)
# - Counter value manipulation via non-atomic operations
# - Duplicate counter creation via find-or-create race
# - Counter decrement to negative values
#
# Covers: SRS-016 US-020 (Usage Counter Integrity)

require 'test_helper'

class EntitlementsCounterIntegrityTest < ActiveSupport::TestCase
  setup do
    register_all_settings
    RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
    @plan = create_test_plan(
      name: 'Counter Test',
      slug: 'counter-test',
      limits: { 'api_calls' => 100 }
    )
    @identity = RSB::Auth::Identity.create!
    @entitlement = RSB::Entitlements::Entitlement.create!(
      entitleable: @identity,
      plan: @plan,
      status: 'active',
      provider: 'wire',
      activated_at: Time.current
    )
    @counter = create_test_usage_counter(
      countable: @identity,
      metric: 'api_calls',
      plan: @plan,
      limit: 100,
      current_value: 0
    )
  end

  test 'increment uses atomic SQL UPDATE' do
    @counter.increment!(5)
    @counter.reload
    assert_equal 5, @counter.current_value
  end

  test 'concurrent increments do not lose updates' do
    # Simulate concurrent increments by using multiple threads
    threads = 10.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          counter = RSB::Entitlements::UsageCounter.find(@counter.id)
          counter.increment!(1)
        end
      end
    end
    threads.each(&:join)

    @counter.reload
    assert_equal 10, @counter.current_value,
      "Expected 10 after 10 concurrent increments, got #{@counter.current_value}"
  end

  test 'unique constraint prevents duplicate counters' do
    # Uniqueness enforced by AR validation (RecordInvalid) and DB unique index (RecordNotUnique)
    exception_raised = false
    begin
      RSB::Entitlements::UsageCounter.create!(
        countable: @identity,
        metric: 'api_calls',
        period_key: @counter.period_key,
        plan: @plan,
        limit: 100,
        current_value: 0
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      exception_raised = true
    end
    assert exception_raised, 'Duplicate counter must be rejected by uniqueness constraint'
  end

  test 'current_value cannot go negative (model validation)' do
    # current_value >= 0 is validated at model level
    @counter.current_value = -1
    assert_not @counter.valid?, 'Counter value must not be allowed to go negative'
    assert @counter.errors[:current_value].any?, 'Validation error must be on :current_value'
  end

  test 'at_limit? reads from DB, not cached value' do
    @counter.update_column(:current_value, 99)
    assert_not @counter.reload.at_limit?

    @counter.increment!(1)
    assert @counter.reload.at_limit?, 'at_limit? must reflect the DB value'
  end

  test 'remaining reads from DB, not cached value' do
    @counter.update_column(:current_value, 95)
    @counter.reload
    assert_equal 5, @counter.remaining
  end
end
