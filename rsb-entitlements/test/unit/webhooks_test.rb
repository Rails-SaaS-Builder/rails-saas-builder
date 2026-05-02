# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class WebhooksTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      def base_args
        {
          provider: 'stripe',
          event_id: 'evt_abc123',
          type: 'customer.subscription.updated',
          payload: { 'data' => { 'x' => 1 } }
        }
      end

      # --- Happy path: first call ---

      test 'first call runs the block, inserts a ProviderEvent row, returns :processed' do
        invocations = 0
        result = Webhooks.process(**base_args) { invocations += 1 }
        assert_equal :processed, result
        assert_equal 1, invocations

        row = ProviderEvent.find_by(provider: 'stripe', event_id: 'evt_abc123')
        assert_not_nil row
        assert_equal 'customer.subscription.updated', row.type
      end

      test 'first call works without a block' do
        result = Webhooks.process(**base_args)
        assert_equal :processed, result
        assert ProviderEvent.exists?(provider: 'stripe', event_id: 'evt_abc123')
      end

      # --- Idempotency: repeat delivery ---

      test 'second call with same (provider, event_id) skips the block, returns :already_processed' do
        Webhooks.process(**base_args) { :first }

        invocations = 0
        result = Webhooks.process(**base_args) { invocations += 1 }
        assert_equal :already_processed, result
        assert_equal 0, invocations
        assert_equal 1, ProviderEvent.where(provider: 'stripe', event_id: 'evt_abc123').count
      end

      test 'different event_id under same provider is not deduped' do
        Webhooks.process(**base_args.merge(event_id: 'evt_1')) { :ok }
        result = Webhooks.process(**base_args.merge(event_id: 'evt_2')) { :ok }
        assert_equal :processed, result
      end

      test 'same event_id under different providers is not deduped' do
        Webhooks.process(**base_args.merge(provider: 'stripe', event_id: 'evt_dup')) { :ok }
        result = Webhooks.process(**base_args.merge(provider: 'revenuecat', event_id: 'evt_dup')) { :ok }
        assert_equal :processed, result
      end

      # --- Block-raise rolls back the ProviderEvent row ---

      test 'block raise rolls back the ProviderEvent row → next call re-processes' do
        # First attempt: block raises mid-way → row should NOT persist.
        assert_raises(RuntimeError) do
          Webhooks.process(**base_args) { raise 'kaboom' }
        end
        assert_nil ProviderEvent.find_by(provider: 'stripe', event_id: 'evt_abc123'),
                   'ProviderEvent row should have been rolled back'

        # Second attempt with the same (provider, event_id) must run the block again.
        invocations = 0
        result = Webhooks.process(**base_args) { invocations += 1 }
        assert_equal :processed, result
        assert_equal 1, invocations
        assert ProviderEvent.exists?(provider: 'stripe', event_id: 'evt_abc123')
      end

      # --- Block return value is irrelevant ---

      test 'block return value does not affect the symbol returned' do
        assert_equal :processed, Webhooks.process(**base_args.merge(event_id: 'evt_ret_1')) { 'something' }
        assert_equal :processed, Webhooks.process(**base_args.merge(event_id: 'evt_ret_2')) { nil }
        assert_equal :processed, Webhooks.process(**base_args.merge(event_id: 'evt_ret_3')) { false }
      end

      # --- Payload jsonb round-trip ---

      test 'payload jsonb round-trips a nested hash' do
        payload = { 'data' => { 'x' => 1, 'nested' => { 'y' => [1, 2, 3] } } }
        Webhooks.process(provider: 'stripe', event_id: 'evt_payload',
                         type: 'test.event', payload: payload) { :ok }
        row = ProviderEvent.find_by(provider: 'stripe', event_id: 'evt_payload')
        assert_equal payload, row.payload
      end

      test 'nil payload is stored as empty hash' do
        Webhooks.process(provider: 'stripe', event_id: 'evt_nil_payload',
                         type: 'test.event', payload: nil) { :ok }
        row = ProviderEvent.find_by(provider: 'stripe', event_id: 'evt_nil_payload')
        assert_equal({}, row.payload)
      end

      # --- Concurrent same-event (Postgres only) ---

      test 'concurrent same-event yields one :processed and one :already_processed; block runs exactly once' do
        skip 'requires Postgres for true concurrent unique-index race' unless postgres?

        barrier = Mutex.new
        ready   = ConditionVariable.new
        ready_count = 0

        results = Concurrent::Array.new
        invocations = Concurrent::AtomicFixnum.new(0)

        threads = 2.times.map do
          Thread.new do
            ::ActiveRecord::Base.connection_pool.with_connection do
              barrier.synchronize do
                ready_count += 1
                ready.broadcast if ready_count == 2
                ready.wait(barrier) while ready_count < 2
              end

              result = Webhooks.process(**base_args.merge(event_id: 'evt_race')) do
                invocations.increment
                sleep 0.05 # widen the window so both threads overlap inside the txn
              end
              results << result
            end
          end
        end
        threads.each(&:join)

        assert_equal 1, invocations.value, 'block must run exactly once across the race'
        assert_equal 2, results.size
        assert_includes results, :processed
        assert_includes results, :already_processed
      end

      private

      def postgres?
        ::ActiveRecord::Base.connection.adapter_name =~ /postgres/i
      end
    end
  end
end
