module RSB
  module Auth
    class InstallGenerator < Rails::Generators::Base
      namespace "rsb:auth:install"
      source_root File.expand_path("templates", __dir__)

      desc "Install rsb-auth: copy migrations, mount routes."

      def copy_migrations
        rake "rsb_auth:install:migrations"
      end

      def mount_routes
        route 'mount RSB::Auth::Engine => "/auth"'
      end

      def print_post_install
        say ""
        say "rsb-auth installed successfully!", :green
        say ""
        say "Next steps:"
        say "  1. rails db:migrate"
        say "  2. Visit /auth/register to register a user"
        say "  3. Visit /auth/session/new to log in"
        say ""
      end
    end
  end
end
