# frozen_string_literal: true

module RSB
  module Entitlements
    # Mixin host applications include on any model that holds entitlements
    # ("subject"). Provides a uniform read surface (+entitled_to?+,
    # +limit_for+, +remaining_for+, +grant_for+, +active_subscription+) and
    # a write surface (+consume!+, +release!+) on top of {Resolver} and
    # {Recorder}.
    #
    # The read methods lazily compute the current period for metered
    # features via {PeriodCalculator} and report values as if the counter
    # were zero-consumed when the stored +period_start+ is older than the
    # computed one -- without mutating the counter row. The actual mutation
    # happens inside {Recorder.consume!}.
    #
    # See TDD-019 §4 (Subject mixin) and §5.3 (Read-only entitlement checks).
    #
    # @example
    #   class Organization < ApplicationRecord
    #     include RSB::Entitlements::Subject
    #   end
    #
    #   org = Organization.find(1)
    #   org.entitled_to?(:api_calls)  # => true
    #   org.remaining_for(:api_calls) # => 950
    #   org.consume!(:api_calls)      # => UsageCounter (consumed: 51)
    module Subject
      extend ActiveSupport::Concern

      # Active/trialing statuses honored by entitlement resolution.
      ACTIVE_STATUSES = %w[active trialing].freeze

      # Returns whether the subject is currently entitled to +feature_key+.
      #
      # For +flag+ features returns the +enabled+ payload from the granting
      # +plan_features+ row. For +metered+ features returns +true+ when the
      # effective (lazy-rolled) consumed value is below the limit, or when
      # the limit is nil (unlimited). For +gauge+ features returns +true+
      # when the stored consumed value is below the limit, or unlimited.
      #
      # @param feature_key [Symbol, String] the feature to check.
      # @return [Boolean] +true+ if the subject is currently entitled.
      def entitled_to?(feature_key)
        grant = Resolver.grant_for(subject: self, feature_key: feature_key)
        return false if grant.nil?

        case grant.feature_kind
        when 'flag'
          grant.enabled == true
        when 'metered'
          return true if grant.limit.nil?

          effective_consumed(grant) < grant.limit
        when 'gauge'
          return true if grant.limit.nil?

          consumed = grant.counter&.consumed || 0
          consumed < grant.limit
        else
          false
        end
      end

      # Returns the limit for +feature_key+ on the active grant.
      #
      # @param feature_key [Symbol, String] the feature to look up.
      # @return [Integer, nil, false] +Integer+ limit, +nil+ for unlimited,
      #   or +false+ when no active grant exists.
      def limit_for(feature_key)
        grant = Resolver.grant_for(subject: self, feature_key: feature_key)
        return false if grant.nil?

        grant.limit
      end

      # Returns the remaining quota for +feature_key+ on the active grant.
      #
      # For metered features the value is computed against the lazily-rolled
      # effective consumed (see TDD §5.3) so callers get correct values
      # across the period boundary without requiring a +consume!+ to refresh
      # state. Result is clamped at zero.
      #
      # @param feature_key [Symbol, String] the feature to look up.
      # @return [Integer, nil] +Integer+ remaining (clamped at 0), +nil+ for
      #   unlimited, or +0+ when no active grant exists.
      def remaining_for(feature_key)
        grant = Resolver.grant_for(subject: self, feature_key: feature_key)
        return 0 if grant.nil?
        return nil if grant.limit.nil?

        [grant.limit - effective_consumed(grant), 0].max
      end

      # Returns a hash summarising the active grant.
      #
      # The returned +consumed+ and +period_start+ values are
      # period-effective: for metered features whose stored +period_start+
      # is older than the current computed period, +consumed+ is reported
      # as +0+ and +period_start+ as the current period start -- without
      # mutating the underlying counter row.
      #
      # @param feature_key [Symbol, String] the feature to look up.
      # @return [Hash{Symbol=>Object}, nil] hash with
      #   +:plan_key+, +:limit+, +:consumed+, +:period_start+, +:period+
      #   keys, or +nil+ when no active grant exists.
      def grant_for(feature_key)
        grant = Resolver.grant_for(subject: self, feature_key: feature_key)
        return nil if grant.nil?

        {
          plan_key: grant.plan_key,
          limit: grant.limit,
          consumed: effective_consumed(grant),
          period_start: effective_period_start(grant),
          period: grant.period
        }
      end

      # Increments the counter for +feature_key+ by +amount+ inside a
      # transaction. Delegates to {Recorder.consume!}.
      #
      # @param feature_key [Symbol, String] the feature to consume.
      # @param amount [Integer] the amount to consume; defaults to 1.
      # @return [RSB::Entitlements::UsageCounter] the updated counter row.
      # @raise [ArgumentError] if +amount <= 0+ or the feature is a flag.
      # @raise [RSB::Entitlements::OverLimit] if no active subscription, no
      #   +plan_features+ row, or insufficient capacity.
      def consume!(feature_key, amount: 1)
        Recorder.consume!(subject: self, feature_key: feature_key, amount: amount)
      end

      # Decrements the gauge counter for +feature_key+ by +amount+ inside a
      # transaction. Delegates to {Recorder.release!}.
      #
      # @param feature_key [Symbol, String] the feature to release.
      # @param amount [Integer] the amount to release; defaults to 1.
      # @return [RSB::Entitlements::UsageCounter] the updated counter row.
      # @raise [ArgumentError] if +amount <= 0+ or the feature is not gauge.
      # @raise [RSB::Entitlements::CannotRelease] if no active grant or
      #   +consumed < amount+.
      def release!(feature_key, amount: 1)
        Recorder.release!(subject: self, feature_key: feature_key, amount: amount)
      end

      # Returns the subject's currently active or trialing subscription.
      #
      # The DB partial unique index guarantees at most one row matches.
      #
      # @return [RSB::Entitlements::Subscription, nil] the active sub or nil.
      def active_subscription
        Subscription.where(
          subject_type: self.class.name,
          subject_id: id,
          status: ACTIVE_STATUSES
        ).first
      end

      private

      # Period-effective consumed value for a grant (TDD §5.3).
      #
      # For non-metered features (flag, gauge) returns the stored consumed
      # value (or 0) — neither has a period concept and PeriodCalculator
      # would raise on +period: nil+. For metered features computes
      # +period_start_now+ via {PeriodCalculator} and returns the stored
      # value when the row is current; +0+ when the stored period is older
      # than the computed one (lazy roll on read — never mutates the row).
      #
      # @param grant [RSB::Entitlements::Resolver::Grant]
      # @return [Integer]
      def effective_consumed(grant)
        return grant.counter&.consumed || 0 unless grant.feature_kind == 'metered'

        period_start_now = PeriodCalculator.period_start_for(
          period: grant.period,
          anchor: grant.subscription.created_at,
          clock: Time.current
        )

        if grant.counter && grant.counter.period_start >= period_start_now
          grant.counter.consumed
        else
          0
        end
      end

      # Period-effective +period_start+ value for a grant (TDD §5.3).
      #
      # For non-metered features (flag, gauge) returns the stored
      # +period_start+ (typically +'-infinity'+ or +nil+). For metered
      # features always returns the currently computed period start.
      #
      # @param grant [RSB::Entitlements::Resolver::Grant]
      # @return [Time, ActiveSupport::TimeWithZone, nil]
      def effective_period_start(grant)
        return grant.counter&.period_start unless grant.feature_kind == 'metered'

        PeriodCalculator.period_start_for(
          period: grant.period,
          anchor: grant.subscription.created_at,
          clock: Time.current
        )
      end
    end
  end
end
