# frozen_string_literal: true

module RSB
  module Admin
    class InstallGenerator < Rails::Generators::Base
      namespace 'rsb:admin:install'
      source_root File.expand_path('templates', __dir__)

      desc 'Install rsb-admin: copy migrations, mount routes, and create seed file.'

      # Copies rsb-admin migrations to the host application.
      # @return [void]
      def copy_migrations
        rake 'rsb_admin:install:migrations'
      end

      # Mounts the rsb-admin engine at /admin in the host application's routes.
      # @return [void]
      def mount_routes
        route 'mount RSB::Admin::Engine => "/admin"'
      end

      # Copies the seed file template to db/seeds/rsb_admin.rb.
      # Uses skip: true to avoid overwriting existing seed files.
      # @return [void]
      def copy_seed_file
        copy_file 'rsb_admin_seeds.rb', 'db/seeds/rsb_admin.rb', skip: true
      end

      # Prints post-installation instructions.
      # @return [void]
      def print_post_install
        say ''
        say 'rsb-admin installed successfully!', :green
        say ''
        say 'Next steps:'
        say '  1. rails db:migrate'
        say '  2. rails rsb:create_admin EMAIL=admin@example.com PASSWORD=changeme'
        say '     OR edit db/seeds/rsb_admin.rb and run: rails db:seed'
        say '  3. Visit /admin/login'
        say ''
      end
    end
  end
end
