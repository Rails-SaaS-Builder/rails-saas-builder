# frozen_string_literal: true

module RSB
  module Auth
    # Registry of invitation notifier classes, keyed by channel.
    # Follows the same pattern as {CredentialRegistry}.
    # Accessed via {RSB::Auth.notifiers}.
    #
    # @example Register a custom notifier
    #   RSB::Auth.notifiers.register(MyApp::TelegramNotifier)
    class NotifierRegistry
      def initialize
        @notifiers = {}
      end

      # Register a notifier subclass.
      # @param notifier_class [Class] must be a subclass of InvitationNotifier::Base
      def register(notifier_class)
        unless notifier_class.is_a?(Class) && notifier_class < InvitationNotifier::Base
          raise ArgumentError, "Expected InvitationNotifier::Base subclass, got #{notifier_class}"
        end

        @notifiers[notifier_class.channel_key.to_sym] = notifier_class
      end

      # Find a notifier by channel key.
      # @param channel_key [Symbol, String]
      # @return [Class, nil]
      def find(channel_key)
        @notifiers[channel_key.to_sym]
      end

      # All registered notifier classes.
      # @return [Array<Class>]
      def all
        @notifiers.values
      end

      # All registered channel keys.
      # @return [Array<Symbol>]
      def keys
        @notifiers.keys
      end
    end
  end
end
