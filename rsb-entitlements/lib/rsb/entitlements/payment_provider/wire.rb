# frozen_string_literal: true

module RSB
  module Entitlements
    module PaymentProvider
      # Built-in wire transfer provider. Implements a manual approval flow:
      # 1. initiate! stores bank details and returns payment instructions
      # 2. Admin approves/rejects via admin panel
      # 3. complete! grants the entitlement, reject! marks as rejected
      #
      # Settings (under entitlements.providers.wire.*):
      # - enabled (boolean, default: true)
      # - instructions (string, default: "") — custom instructions template
      # - bank_name (string, default: "")
      # - account_number (string, default: "")
      # - routing_number (string, default: "")
      # - auto_expire_hours (integer, default: 72)
      class Wire < Base
        def self.provider_key
          :wire
        end

        def self.provider_label
          'Wire Transfer'
        end

        def self.manual_resolution?
          true
        end

        def self.admin_actions
          %i[approve reject]
        end

        def self.refundable?
          false
        end

        settings_schema do
          setting :instructions,
                  type: :string,
                  default: '',
                  depends_on: 'entitlements.providers.wire.enabled',
                  description: 'Custom payment instructions template (supports %<amount>s, %<currency>s, %<bank_name>s, %<account_number>s, %<routing_number>s)'

          setting :bank_name,
                  type: :string,
                  default: '',
                  depends_on: 'entitlements.providers.wire.enabled',
                  description: 'Bank name for wire transfer details'

          setting :account_number,
                  type: :string,
                  default: '',
                  depends_on: 'entitlements.providers.wire.enabled',
                  description: 'Account number for wire transfer'

          setting :routing_number,
                  type: :string,
                  default: '',
                  depends_on: 'entitlements.providers.wire.enabled',
                  description: 'Routing number for wire transfer'

          setting :auto_expire_hours,
                  type: :integer,
                  default: 72,
                  depends_on: 'entitlements.providers.wire.enabled',
                  description: 'Hours before wire transfer requests auto-expire'
        end

        # Start the wire transfer flow.
        # Stores bank details in provider_data, sets expiry, transitions to processing.
        #
        # @return [Hash] { instructions: "Please wire $X to..." }
        def initiate!
          bank_name = setting('bank_name')
          account_number = setting('account_number')
          routing_number = setting('routing_number')
          auto_expire_hours = setting('auto_expire_hours').to_i
          custom_instructions = setting('instructions')

          payment_request.update!(
            status: 'processing',
            expires_at: auto_expire_hours.hours.from_now,
            provider_data: {
              'bank_name' => bank_name,
              'account_number' => account_number,
              'routing_number' => routing_number,
              'instructions_sent_at' => Time.current.iso8601
            }
          )

          amount = format_amount(payment_request.amount_cents, payment_request.currency)
          instructions = build_instructions(
            custom_instructions,
            amount: amount,
            currency: payment_request.currency,
            bank_name: bank_name,
            account_number: account_number,
            routing_number: routing_number
          )

          { instructions: instructions }
        end

        # Approve the wire transfer. Grants entitlement to the requestable.
        #
        # @param params [Hash] unused
        # @return [void]
        def complete!(_params = {})
          return unless payment_request.actionable?

          entitlement = payment_request.requestable.grant_entitlement(
            plan: payment_request.plan,
            provider: payment_request.provider_key,
            metadata: payment_request.metadata
          )

          payment_request.update!(
            status: 'approved',
            entitlement: entitlement
          )
        end

        # Reject the wire transfer. No entitlement changes.
        #
        # @param params [Hash] unused
        # @return [void]
        def reject!(_params = {})
          return unless payment_request.actionable?

          payment_request.update!(status: 'rejected')
        end

        # Provider-specific details for admin show page.
        #
        # @return [Hash] { "Bank Name" => "...", ... }
        def admin_details
          data = payment_request.provider_data || {}
          details = {}
          details['Bank Name'] = data['bank_name'] if data['bank_name'].present?
          details['Account Number'] = data['account_number'] if data['account_number'].present?
          details['Routing Number'] = data['routing_number'] if data['routing_number'].present?
          details['Instructions Sent At'] = data['instructions_sent_at'] if data['instructions_sent_at'].present?
          details
        end

        private

        # Read a wire provider setting.
        #
        # @param key [String] setting key (without provider prefix)
        # @return [Object] the setting value
        def setting(key)
          RSB::Settings.get("entitlements.providers.wire.#{key}")
        end

        # Format cents into a human-readable amount string.
        #
        # @param cents [Integer]
        # @param currency [String]
        # @return [String] e.g., "$99.00"
        def format_amount(cents, currency)
          dollars = cents / 100.0
          symbol = currency.upcase == 'USD' ? '$' : currency.upcase
          "#{symbol}#{'%.2f' % dollars}"
        end

        # Build instructions string from template or default.
        #
        # @param template [String] custom template (may be blank)
        # @param kwargs [Hash] substitution variables
        # @return [String]
        def build_instructions(template, **kwargs)
          if template.present?
            template % kwargs
          else
            parts = ["Please wire #{kwargs[:amount]} to"]
            parts << kwargs[:bank_name] if kwargs[:bank_name].present?
            parts << "(Account: #{kwargs[:account_number]})" if kwargs[:account_number].present?
            parts << "(Routing: #{kwargs[:routing_number]})" if kwargs[:routing_number].present?
            parts.join(' ')
          end
        end
      end
    end
  end
end
