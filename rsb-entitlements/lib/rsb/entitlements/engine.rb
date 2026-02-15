# frozen_string_literal: true

module RSB
  module Entitlements
    class Engine < ::Rails::Engine
      isolate_namespace RSB::Entitlements

      # FIXME: Move admin integration to separate gem!
      # Exclude admin controllers from autoloading when rsb-admin is not present.
      # These controllers inherit from RSB::Admin::AdminController and can only
      # be loaded when rsb-admin is in the bundle.
      initializer 'rsb_entitlements.exclude_admin_controllers', before: :set_autoload_paths do
        unless defined?(RSB::Admin::Engine)
          Rails.autoloaders.main.ignore(root.join('app', 'controllers', 'rsb', 'entitlements', 'admin'))
        end
      end

      # Register settings schema with rsb-settings
      initializer 'rsb_entitlements.register_settings', after: 'rsb_settings.ready' do
        RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
      end

      # Signal readiness — provider extensions hook in after this
      initializer 'rsb_entitlements.ready' do
        # Register built-in providers
        RSB::Entitlements.providers.register(RSB::Entitlements::PaymentProvider::Wire)
      end

      # Load i18n translations for admin labels
      initializer 'rsb_entitlements.i18n' do
        config.i18n.load_path += Dir[RSB::Entitlements::Engine.root.join('config', 'locales', '**', '*.yml')]
      end

      # Admin integration via lazy on_load hook
      # Registers Plan and Entitlement resources with explicit columns, filters, and form fields,
      # plus a UsageCounters page with custom actions for monitoring and resetting counters.
      initializer 'rsb_entitlements.admin_hooks' do
        ActiveSupport.on_load(:rsb_admin) do |admin_registry|
          admin_registry.register_category 'Billing' do
            resource RSB::Entitlements::Plan,
                     icon: 'credit-card',
                     actions: %i[index show new create edit update destroy],
                     controller: 'rsb/entitlements/admin/plans',
                     default_sort: { column: :name, direction: :asc } do
              column :id, link: true
              column :name, sortable: true
              column :slug, visible_on: [:show]
              column :interval, formatter: :badge
              column :price_cents, label: 'Price', sortable: true
              column :currency, visible_on: [:show]
              column :active, formatter: :badge
              column :features, formatter: :json, visible_on: [:show]
              column :limits, formatter: :json, visible_on: [:show]
              column :metadata, formatter: :json, visible_on: [:show]
              column :created_at, formatter: :datetime, visible_on: [:show]

              filter :active, type: :boolean
              filter :interval, type: :select, options: %w[monthly yearly one_time]

              form_field :name, type: :text, required: true
              form_field :slug, type: :text, required: true, hint: 'URL-friendly identifier'
              form_field :interval, type: :select, options: %w[monthly yearly one_time], required: true
              form_field :price_cents, type: :number, required: true, label: 'Price (cents)'
              form_field :currency, type: :text, hint: 'ISO 4217 code (e.g., USD)'
              form_field :active, type: :checkbox
              form_field :features, type: :json, hint: 'JSON object of feature flags'
              form_field :limits, type: :json, hint: 'JSON object of usage limits'
              form_field :metadata, type: :json, hint: 'Arbitrary metadata'
            end

            resource RSB::Entitlements::Entitlement,
                     icon: 'shield',
                     actions: %i[index show grant revoke activate] do
              column :id, link: true
              column :plan_id, label: 'Plan'
              column :entitleable_type, label: 'Type'
              column :entitleable_id, label: 'Owner ID'
              column :status, formatter: :badge
              column :starts_at, formatter: :datetime, visible_on: [:show]
              column :ends_at, formatter: :datetime, visible_on: [:show]
              column :created_at, formatter: :datetime, visible_on: [:show]

              filter :status, type: :select, options: %w[active expired cancelled]
              filter :entitleable_type, type: :text
            end

            resource RSB::Entitlements::PaymentRequest,
                     icon: 'receipt',
                     actions: %i[index show approve reject refund],
                     controller: 'rsb/entitlements/admin/payment_requests',
                     default_sort: { column: :created_at, direction: :desc },
                     per_page: 20 do
              column :id, link: true
              column :requestable_type, label: 'Type'
              column :requestable_id, label: 'Owner ID'
              column :plan_id, label: 'Plan'
              column :provider_key, formatter: :badge
              column :status, formatter: :badge
              column :amount_cents, label: 'Amount'
              column :currency
              column :created_at, formatter: :datetime, visible_on: %i[index show]
              column :provider_ref, visible_on: [:show]
              column :resolved_by, visible_on: [:show]
              column :resolved_at, formatter: :datetime, visible_on: [:show]
              column :admin_note, visible_on: [:show]
              column :expires_at, formatter: :datetime, visible_on: [:show]

              filter :status, type: :select,
                              options: RSB::Entitlements::PaymentRequest::STATUSES
              filter :provider_key, type: :select,
                                    options: -> { RSB::Entitlements.providers.all.map { |d| d.key.to_s } }
              filter :requestable_type, type: :text
            end

            page :usage_counters,
                 label: 'Usage Monitoring',
                 icon: 'bar-chart',
                 controller: 'rsb/entitlements/admin/usage_counters',
                 actions: [
                   { key: :index, label: 'Overview' },
                   { key: :trend, label: 'Trend' }
                 ]
          end
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
