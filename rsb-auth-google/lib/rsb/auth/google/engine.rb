# frozen_string_literal: true

module RSB
  module Auth
    module Google
      class Engine < ::Rails::Engine
        isolate_namespace RSB::Auth::Google

        initializer 'rsb_auth_google.register_settings', after: 'rsb_settings.ready' do
          RSB::Settings.registry.register(RSB::Auth::Google::SettingsSchema.build)
        end

        initializer 'rsb_auth_google.register_credential', after: 'rsb_auth.ready' do
          RSB::Auth.credentials.register(
            RSB::Auth::CredentialDefinition.new(
              key: :google,
              class_name: 'RSB::Auth::Google::Credential',
              authenticatable: true,
              registerable: true,
              label: 'Google',
              icon: 'google',
              form_partial: 'rsb/auth/google/credentials/google',
              redirect_url: '/auth/oauth/google',
              admin_form_partial: nil
            )
          )

          RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings

          # Override per-credential defaults for Google via initializer-level config.
          # These are resolved without DB access (resolver chain: DB > initializer > ENV > default).
          RSB::Settings.configure do |config|
            config.set 'auth.credentials.google.verification_required', false
            config.set 'auth.credentials.google.auto_verify_on_signup', true
            config.set 'auth.credentials.google.allow_login_unverified', true

            if RSB::Auth::Google.configuration.client_id.present?
              config.set 'auth.credentials.google.client_id', RSB::Auth::Google.configuration.client_id
            end
            if RSB::Auth::Google.configuration.client_secret.present?
              config.set 'auth.credentials.google.client_secret', RSB::Auth::Google.configuration.client_secret
            end
          end
        end

        initializer 'rsb_auth_google.admin_hooks' do
          ActiveSupport.on_load(:rsb_admin) do |_admin_registry|
            # Google credentials are visible through rsb-auth's Identity admin resource.
            # No additional admin resources needed for v1.
          end
        end

        initializer 'rsb_auth_google.append_migrations' do |app|
          config.paths['db/migrate'].expanded.each do |path|
            app.config.paths['db/migrate'] << path unless app.config.paths['db/migrate'].include?(path)
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
