# frozen_string_literal: true

module RSB
  module Entitlements
    # Multi-subscriber synchronous event registry.
    #
    # Hosts register subscribers via {RSB::Entitlements.on}, e.g.
    #
    #   RSB::Entitlements.on(:plan_changed) do |subscription, from_key, to_key|
    #     # ...
    #   end
    #
    # The gem fires events via {fire}. Subscribers run in registration order,
    # synchronously, in the calling thread and (where applicable) calling
    # transaction. A subscriber that raises propagates the exception; later
    # subscribers for the same event are not invoked.
    class HookRegistry
      def initialize
        @subscribers = Hash.new { |h, k| h[k] = [] }
      end

      # Register a subscriber for the given event.
      #
      # @param event [Symbol] event name
      # @yield [*args] called with whatever args {fire} passes
      # @return [Proc] the registered block (for symmetry; not used by the gem)
      def on(event, &block)
        @subscribers[event] << block
        block
      end

      # Invoke every subscriber for `event` in registration order.
      # Passes `*args` through to each subscriber.
      #
      # If a subscriber raises, the exception propagates and remaining
      # subscribers do NOT fire.
      #
      # @param event [Symbol]
      # @param args [Array] forwarded to each subscriber
      # @return [void]
      def fire(event, *args)
        subs = @subscribers[event]
        return if subs.nil? || subs.empty?

        subs.each { |sub| sub.call(*args) }
        nil
      end

      # Remove every registered subscriber. Used by {RSB::Entitlements.reset!}
      # in test setup/teardown.
      #
      # @return [void]
      def reset!
        @subscribers = Hash.new { |h, k| h[k] = [] }
        nil
      end
    end
  end
end
