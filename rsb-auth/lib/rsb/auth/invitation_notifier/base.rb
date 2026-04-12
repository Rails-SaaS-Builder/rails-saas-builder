# frozen_string_literal: true

module RSB
  module Auth
    module InvitationNotifier
      class Base
        # Unique key identifying this channel. Used in DB (channel column) and admin UI.
        # Subclasses MUST override. Returns a Symbol.
        # @return [Symbol]
        def self.channel_key
          raise NotImplementedError, "#{name}.channel_key must be implemented"
        end

        # Human-readable label for admin UI dropdown.
        # @return [String]
        def self.label
          channel_key.to_s.titleize
        end

        # Form fields for the admin deliver form.
        # Each notifier declares ALL its inputs -- including the recipient.
        # The field with `recipient: true` is stored in the delivery record.
        #
        # Each field is a Hash with:
        #   key:         [Symbol]  field identifier, passed in `fields` hash to deliver!
        #   type:        [Symbol]  :text, :textarea, :select, :number, :email
        #   label:       [String]  human-readable label
        #   required:    [Boolean] default false
        #   default:     [String, nil]  pre-filled value
        #   placeholder: [String, nil]  input placeholder
        #   options:     [Array<String>, nil]  for :select type only
        #   recipient:   [Boolean] marks the field as the recipient (exactly one per notifier, stored in DB)
        #
        # @return [Array<Hash>]
        def self.form_fields
          raise NotImplementedError, "#{name}.form_fields must be implemented"
        end

        # Convenience: extracts the recipient field definition.
        # @return [Hash, nil] the field with `recipient: true`
        def self.recipient_field
          form_fields.find { |f| f[:recipient] }
        end

        # Delivers the invitation notification. Subclasses MUST implement.
        #
        # @param invitation [Invitation] the invitation to deliver
        # @param fields [Hash] all form field values, keyed by field key (includes recipient)
        def deliver!(invitation, fields: {})
          raise NotImplementedError, "#{self.class}#deliver! must be implemented"
        end
      end
    end
  end
end
