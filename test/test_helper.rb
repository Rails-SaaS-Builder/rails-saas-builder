# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'

# Include all gem test helpers
require 'rsb/settings/test_helper'
require 'rsb/auth/test_helper'
require 'rsb/entitlements/test_helper'
require 'rsb/entitlements/stripe/test_helper'
require 'rsb/admin/test_kit/helpers'

# Run all migrations from all sub-gems + dummy app
ActiveRecord::MigrationContext.new(
  Rails.application.config.paths['db/migrate'].to_a
).migrate
ActiveRecord::Migration.maintain_test_schema!

# Reset schema cache for models that may have been loaded before migrations ran
ActiveRecord::Base.descendants.each(&:reset_column_information)

module ActiveSupport
  class TestCase
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
    include RSB::Entitlements::TestHelper
    include RSB::Entitlements::Stripe::TestHelper

    # Re-register all settings schemas (needed after reset! clears registries between tests)
    def register_all_settings
      RSB::Settings.registry.register(RSB::Settings::SeoSettingsSchema.build)
      RSB::Settings.registry.register(RSB::Auth.settings_schema)
      RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
      RSB::Settings.registry.register(RSB::Admin.settings_schema)
    end

    # Re-register all built-in credential types, per-credential enabled settings,
    # and last-type validation callbacks
    def register_all_credentials
      register_all_auth_credentials # all three types with icon/form_partial from RSB::Auth::TestHelper
      RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
      RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation
    end

    # Re-register admin categories (on_load hooks only fire once at boot)
    def register_all_admin_categories
      RSB::Admin.registry.register_category 'Authentication' do
        resource RSB::Auth::Identity,
                 icon: 'users',
                 actions: %i[index show new create suspend activate deactivate
                             revoke_credential restore_credential restore
                             new_credential add_credential verify_credential resend_verification],
                 controller: 'rsb/auth/admin/identities',
                 per_page: 30,
                 default_sort: { column: :created_at, direction: :desc },
                 search_fields: [:id] do
          column :id, link: true
          column :status, formatter: :badge
          column :primary_identifier, label: 'Email / Username', visible_on: %i[index show]
          column :credentials_count, label: 'Credentials', visible_on: [:index]
          column :created_at, formatter: :datetime, visible_on: [:show]
          column :updated_at, formatter: :datetime, visible_on: [:show]

          filter :status, type: :select, options: %w[active suspended deactivated deleted]

          filter :credential, label: 'Email / Username / Phone', type: :text,
                              scope: lambda { |rel, val|
                                rel.joins(:credentials)
                                .where('rsb_auth_credentials.identifier LIKE ?', "%#{val}%")
                                .distinct
                              }

          filter :credential_type, label: 'Credential Type', type: :select,
                                   options: -> { RSB::Auth.credentials.all.map { |d| d.class_name.demodulize } },
                                   scope: lambda { |rel, val|
                                     rel.joins(:credentials)
                                     .where(rsb_auth_credentials: { type: "RSB::Auth::Credential::#{val}" })
                                     .distinct
                                   }
        end

        resource RSB::Auth::Invitation,
                 icon: 'mail',
                 actions: %i[index new create revoke] do
          column :id, link: true
          column :email
          column :token, visible_on: [:show]
          column :status, formatter: :badge, visible_on: [:index]
          column :invited_by_type, label: 'Invited By', visible_on: [:show]
          column :expires_at, formatter: :datetime
          column :accepted_at, formatter: :datetime, visible_on: [:show]

          filter :email, type: :text
          filter :status, type: :select, options: %w[pending accepted expired revoked]

          form_field :email, type: :email, required: true
        end

        page :sessions_management,
             label: 'Active Sessions',
             icon: 'monitor',
             controller: 'rsb/auth/admin/sessions_management',
             actions: [
               { key: :index, label: 'Active Sessions' },
               { key: :destroy, label: 'Revoke', method: :delete }
             ]
      end

      RSB::Admin.registry.register_category 'Billing' do
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

    # Alias for test compatibility
    alias register_all_admin_categories_v2 register_all_admin_categories
    alias register_all_admin register_all_admin_categories
  end
end

module ActionDispatch
  class IntegrationTest
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
    include RSB::Entitlements::TestHelper
    include RSB::Entitlements::Stripe::TestHelper
    include RSB::Admin::TestKit::Helpers
  end
end
