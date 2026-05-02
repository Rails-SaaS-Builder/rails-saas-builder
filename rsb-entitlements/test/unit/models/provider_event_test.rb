# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class ProviderEventTest < ActiveSupport::TestCase
      include RSB::Entitlements::TestHelper

      def base(**overrides)
        {
          provider: 'stripe',
          event_id: 'evt_001',
          type: 'customer.subscription.updated',
          payload: { 'object' => 'event', 'foo' => 'bar' }
        }.merge(overrides)
      end

      # --- Validations ---

      test 'requires provider, event_id, type, payload' do
        e = ProviderEvent.new
        refute e.valid?
        %i[provider event_id type payload].each do |attr|
          assert e.errors[attr].any?, "expected validation error on #{attr}"
        end
      end

      test 'persists with all required attributes' do
        e = ProviderEvent.create!(base)
        assert_predicate e, :persisted?
      end

      # --- DB-enforced uniqueness on (provider, event_id) ---

      test '(provider, event_id) is unique at the DB layer' do
        ProviderEvent.create!(base)
        assert_raises(ActiveRecord::RecordNotUnique) do
          # Bypass Rails-side validation so the DB unique index does the rejecting.
          ProviderEvent.new(base).save!(validate: false)
        end
      end

      test 'same event_id is allowed across different providers' do
        ProviderEvent.create!(base.merge(provider: 'stripe',     event_id: 'evt_xyz'))
        ProviderEvent.create!(base.merge(provider: 'revenuecat', event_id: 'evt_xyz'))
        assert_equal 2, ProviderEvent.where(event_id: 'evt_xyz').count
      end

      # --- payload is jsonb (round-trip) ---

      test 'payload round-trips a hash through jsonb' do
        payload = {
          'id' => 'evt_001',
          'data' => { 'object' => { 'id' => 'sub_123', 'status' => 'active' } },
          'list' => [1, 2, 3]
        }
        e = ProviderEvent.create!(base.merge(payload: payload))
        e.reload
        assert_equal payload, e.payload
        assert_equal 'sub_123', e.payload.dig('data', 'object', 'id')
      end
    end
  end
end
