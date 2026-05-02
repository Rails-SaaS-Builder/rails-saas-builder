# frozen_string_literal: true

module RSB
  module Entitlements
    # Webhook idempotency ledger.
    #
    # One row per `(provider, event_id)` — DB-enforced via the unique index
    # on those two columns. Inserted by {Webhooks.process} (see Task 13)
    # before the adapter's block runs; on insert collision, the call returns
    # `:already_processed` and the block is skipped.
    #
    # **Hosts own retention.** The gem ships the table and indexes; partitioning
    # and pruning are the host's operational concern (TDD §3, SRS US-009).
    class ProviderEvent < ApplicationRecord
      # `type` is a column on this table holding the provider's event type
      # (e.g., `customer.subscription.updated`); it is **not** STI.
      self.inheritance_column = nil

      validates :provider, presence: true
      validates :event_id, presence: true
      validates :type,     presence: true
      validates :payload,  presence: true
      validates :event_id, uniqueness: { scope: :provider }
    end
  end
end
