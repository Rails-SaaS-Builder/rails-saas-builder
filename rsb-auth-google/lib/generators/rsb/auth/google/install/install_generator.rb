# frozen_string_literal: true

module RSB
  module Auth
    module Google
      class InstallGenerator < Rails::Generators::Base
        namespace 'rsb:auth:google:install'
        source_root File.expand_path('templates', __dir__)

        desc 'Install rsb-auth-google: copy migrations (if needed), mount routes, create initializer.'

        # Copies the provider_uid migration only if the column does not already
        # exist on the rsb_auth_credentials table. This enables multiple OAuth
        # gems to share the same column without migration conflicts.
        #
        # @return [void]
        def copy_migrations
          if provider_uid_column_exists?
            say 'provider_uid column already exists on rsb_auth_credentials, skipping migration', :yellow
          else
            rake 'rsb_auth_google:install:migrations'
          end
        end

        # Mounts the rsb-auth-google engine at /auth/oauth/google in the
        # host application's routes.rb.
        #
        # @return [void]
        def mount_routes
          route 'mount RSB::Auth::Google::Engine => "/auth/oauth/google"'
        end

        # Copies the initializer template with client_id / client_secret
        # placeholders.
        #
        # @return [void]
        def create_initializer
          template 'initializer.rb', 'config/initializers/rsb_auth_google.rb'
        end

        # Prints post-installation instructions.
        #
        # @return [void]
        def print_post_install
          say ''
          say 'rsb-auth-google installed successfully!', :green
          say ''
          say 'Next steps:'
          say '  1. rails db:migrate'
          say '  2. Set your Google OAuth credentials:'
          say '     - In config/initializers/rsb_auth_google.rb, OR'
          say '     - In the admin panel under Settings > Google OAuth, OR'
          say '     - Via ENV: RSB_AUTH_CREDENTIALS_GOOGLE_CLIENT_ID and RSB_AUTH_CREDENTIALS_GOOGLE_CLIENT_SECRET'
          say '  3. Register your callback URL with Google Cloud Console:'
          say '     https://your-app.com/auth/oauth/google/callback'
          say '  4. Visit /auth/session/new to see the Google sign-in button'
          say ''
        end

        private

        def provider_uid_column_exists?
          require 'active_record'
          ActiveRecord::Base.connection.column_exists?(:rsb_auth_credentials, :provider_uid)
        rescue StandardError
          false
        end
      end
    end
  end
end
