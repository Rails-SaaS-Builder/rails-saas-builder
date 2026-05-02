# frozen_string_literal: true

module RSB
  module Entitlements
    # Stateless single-grant lookup. Given (subject, feature_key) returns a
    # {Grant} value object describing the subject's currently active grant for
    # that feature, or +nil+ if no grant exists.
    #
    # The resolver never mutates state and never lazily rolls usage periods —
    # callers (the +Subject+ concern's read-only helpers and {Recorder}) own
    # period semantics. See TDD-019 §5.2 for the full algorithm.
    #
    # @example
    #   grant = RSB::Entitlements::Resolver.grant_for(
    #     subject: workspace, feature_key: :api_calls
    #   )
    #   if grant
    #     grant.feature_kind # => "metered"
    #     grant.limit        # => 1000
    #     grant.period       # => "month"
    #     grant.counter      # => UsageCounter or nil
    #   end
    module Resolver
      # Immutable bundle returned by {grant_for}.
      #
      # @!attribute [r] subscription
      #   @return [RSB::Entitlements::Subscription] the subject's active subscription
      # @!attribute [r] plan_key
      #   @return [String] the plan_key from the matched plan_features row
      # @!attribute [r] feature_kind
      #   @return [String] one of "flag", "metered", "gauge"
      # @!attribute [r] enabled
      #   @return [Boolean, nil] flag-only payload; nil for metered/gauge
      # @!attribute [r] limit
      #   @return [Integer, nil] limit_value; nil = unlimited (metered/gauge only)
      # @!attribute [r] period
      #   @return [String, nil] reset cadence for metered features; nil for flag/gauge
      # @!attribute [r] counter
      #   @return [RSB::Entitlements::UsageCounter, nil] may be nil if not yet created
      Grant = Data.define(
        :subscription, :plan_key, :feature_kind, :enabled, :limit, :period, :counter
      )

      # Resolve the active grant for +subject+ on +feature_key+.
      #
      # @param subject [Object] any object responding to +.id+ whose +.class.name+
      #   has been used as a subscription's +subject_type+.
      # @param feature_key [String, Symbol] the feature key to resolve.
      # @return [Grant, nil] the resolved grant, or nil when the subject has no
      #   active subscription, or the active subscription's plan does not grant
      #   this feature.
      def self.grant_for(subject:, feature_key:)
        feature_key_str = feature_key.to_s
        subject_type    = subject.class.name
        subject_id      = subject.id

        sub = Subscription.where(
          subject_type: subject_type,
          subject_id: subject_id,
          status: %w[active trialing]
        ).first
        return nil if sub.nil?

        pf = PlanFeature.find_by(plan_key: sub.plan_key, feature_key: feature_key_str)
        return nil if pf.nil?

        # Feature row should always exist when a plan_features row references it
        # (FK enforced at the DB level). find_by! signals an internal data-integrity
        # violation if it ever doesn't.
        feature = Feature.find_by!(key: feature_key_str)

        counter = UsageCounter.find_by(
          subject_type: subject_type,
          subject_id: subject_id,
          feature_key: feature_key_str
        )

        Grant.new(
          subscription: sub,
          plan_key: pf.plan_key,
          feature_kind: feature.kind,
          enabled: pf.enabled,
          limit: pf.limit_value,
          period: pf.period,
          counter: counter
        )
      end
    end
  end
end
