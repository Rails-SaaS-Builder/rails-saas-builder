# frozen_string_literal: true

module RSB
  module Entitlements
    # Raised by `before_destroy` on Feature/Plan models. Hard-deletes are
    # irreversible architecturally — keys are referenced by subscriptions,
    # plan_features, and usage_counters. Use `archived_at` instead.
    class HardDeleteForbidden < StandardError; end

    # Raised by `Recorder#consume!` when:
    # - the subject has no active subscription, OR
    # - the active subscription's plan has no `plan_features` row for the feature, OR
    # - the requested amount would push `consumed` past `limit_value`.
    #
    # Always paired with a `:overage_blocked` hook fire (see TDD §5.4).
    class OverLimit < StandardError; end

    # Raised by `Recorder#release!` when:
    # - no active grant exists for (subject, feature), OR
    # - `consumed < amount` (release would drive the counter negative).
    #
    # Gauge-only — `release!` on flag/metered features raises `ArgumentError`,
    # not this error. See TDD §5.5.
    class CannotRelease < StandardError; end
  end
end
