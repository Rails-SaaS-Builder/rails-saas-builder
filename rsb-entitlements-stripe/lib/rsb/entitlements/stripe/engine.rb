module RSB
  module Entitlements
    module Stripe
      class Engine < ::Rails::Engine
        isolate_namespace RSB::Entitlements::Stripe

        # Register the Stripe provider after rsb-entitlements is ready.
        # This triggers settings registration via the provider's settings_schema.
        initializer "rsb_entitlements_stripe.register_provider", after: "rsb_entitlements.ready" do
          RSB::Entitlements.providers.register(RSB::Entitlements::Stripe::PaymentProvider)
        end

        initializer "rsb_entitlements_stripe.middleware" do |app|
          app.middleware.use RSB::Entitlements::Stripe::WebhookMiddleware
        end

        # Admin integration — register Stripe-specific UI hooks if rsb-admin is present.
        # This is a no-op if rsb-admin is not installed.
        initializer "rsb_entitlements_stripe.admin_hooks" do
          ActiveSupport.on_load(:rsb_admin) do |admin_registry|
            # No additional resources to register — Stripe uses the existing
            # PaymentRequest resource in the "Billing" category (registered by rsb-entitlements).
            # The StripeProvider#admin_details method provides Stripe-specific data
            # on the PaymentRequest show page automatically.
            #
            # The provider's `manual_resolution?: false` means no approve/reject buttons.
            # The provider's `admin_actions: [:refund]` enables the refund button.
            # The provider's `refundable?: true` enables refund functionality.
          end
        end

        config.generators do |g|
          g.test_framework :minitest, fixture: false
          g.assets false
          g.helper false
        end
      end
    end
  end
end
