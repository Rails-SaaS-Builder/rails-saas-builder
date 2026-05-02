# frozen_string_literal: true

module RSB
  module Entitlements
    # Recorder — sole entry point for mutating `rsb_entitlements_usage_counters`.
    #
    # Both methods run inside a single ActiveRecord transaction. On failure paths
    # they fire a hook before raising so subscribers see the attempt; on success
    # they commit and return the persisted counter row.
    #
    # @see RSB::Entitlements::Resolver
    # @see RSB::Entitlements::PeriodCalculator
    # @see RSB::Entitlements::HookRegistry
    module Recorder
      module_function

      # Increments a metered or gauge counter. For metered features rolls the
      # period in place when the stored `period_start` is older than the
      # current period start (anchored to the active subscription's `created_at`).
      #
      # @param subject [Object] polymorphic owner with `id` and `class.name`
      # @param feature_key [String, Symbol] feature being consumed
      # @param amount [Integer] positive integer; raises ArgumentError otherwise
      # @return [RSB::Entitlements::UsageCounter] the updated counter row
      # @raise [ArgumentError] when `amount <= 0` or `feature.kind == 'flag'`
      # @raise [RSB::Entitlements::OverLimit] when no active grant or capacity exhausted
      #
      # @example Metered consume
      #   RSB::Entitlements::Recorder.consume!(subject: workspace, feature_key: :api_calls, amount: 1)
      #
      # @example Gauge consume
      #   RSB::Entitlements::Recorder.consume!(subject: workspace, feature_key: :seats, amount: 3)
      def consume!(subject:, feature_key:, amount:)
        raise ArgumentError, 'amount must be > 0' unless amount.is_a?(Integer) && amount.positive?

        feature_key  = feature_key.to_s
        subject_type = subject.class.name
        subject_id   = subject.id

        ActiveRecord::Base.transaction do
          grant = Resolver.grant_for(subject: subject, feature_key: feature_key)

          if grant.nil?
            RSB::Entitlements.hooks.fire(:overage_blocked, subject, feature_key, amount)
            raise OverLimit, "no active grant for #{feature_key}"
          end

          case grant.feature_kind
          when 'flag'
            raise ArgumentError, 'consume! is not valid for flag features (use entitled_to?)'
          when 'metered', 'gauge'
            # fall through to counter logic
          else
            raise ArgumentError, "unknown feature kind: #{grant.feature_kind.inspect}"
          end

          period_start_now =
            if grant.feature_kind == 'gauge'
              # Gauge counters permanently store -infinity as period_start.
              # Use the existing counter's value if present (idempotent), or fall
              # back to -Float::INFINITY which Rails' PostgreSQL adapter serialises
              # as the PG special timestamp '-infinity'.
              grant.counter&.period_start || -Float::INFINITY
            else
              PeriodCalculator.period_start_for(
                period: grant.period,
                anchor: grant.subscription.created_at,
                clock: Time.current
              )
            end

          counter = UsageCounter.lock_or_init(
            subject_type: subject_type,
            subject_id: subject_id,
            feature_key: feature_key,
            default_period_start: period_start_now
          )

          period_rolled = false
          if grant.feature_kind == 'metered' && counter.period_start < period_start_now
            counter.period_start = period_start_now
            counter.consumed     = 0
            period_rolled        = true
          end

          capacity_ok = grant.limit.nil? || (counter.consumed + amount) <= grant.limit

          unless capacity_ok
            RSB::Entitlements.hooks.fire(:overage_blocked, subject, feature_key, amount)
            raise OverLimit, "feature #{feature_key} over limit"
          end

          counter.consumed += amount
          counter.save!

          if period_rolled
            RSB::Entitlements.hooks.fire(:period_rolled, subject, feature_key, counter.period_start)
          end

          counter
        end
      end

      # Decrements a gauge counter. Gauge features only.
      #
      # @param subject [Object] polymorphic owner with `id` and `class.name`
      # @param feature_key [String, Symbol] gauge feature being released
      # @param amount [Integer] positive integer; raises ArgumentError otherwise
      # @return [RSB::Entitlements::UsageCounter] the updated counter row
      # @raise [ArgumentError] when `amount <= 0` or feature kind is not `gauge`
      # @raise [RSB::Entitlements::CannotRelease] when no active grant or `consumed < amount`
      #
      # @example Release a gauge slot
      #   RSB::Entitlements::Recorder.release!(subject: workspace, feature_key: :seats, amount: 1)
      def release!(subject:, feature_key:, amount:)
        raise ArgumentError, 'amount must be > 0' unless amount.is_a?(Integer) && amount.positive?

        feature_key  = feature_key.to_s
        subject_type = subject.class.name
        subject_id   = subject.id

        ActiveRecord::Base.transaction do
          grant = Resolver.grant_for(subject: subject, feature_key: feature_key)

          if grant.nil?
            RSB::Entitlements.hooks.fire(:release_blocked, subject, feature_key, amount)
            raise CannotRelease, "no active grant for #{feature_key}"
          end

          unless grant.feature_kind == 'gauge'
            raise ArgumentError, 'release! is gauge-only; use consume! with a metered or flag feature'
          end

          counter = UsageCounter.lock_or_init(
            subject_type: subject_type,
            subject_id: subject_id,
            feature_key: feature_key,
            default_period_start: -Float::INFINITY
          )

          if counter.consumed < amount
            RSB::Entitlements.hooks.fire(:release_blocked, subject, feature_key, amount)
            raise CannotRelease, "feature #{feature_key} consumed (#{counter.consumed}) < amount (#{amount})"
          end

          counter.consumed -= amount
          counter.save!

          counter
        end
      end
    end
  end
end
