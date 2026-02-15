# frozen_string_literal: true

module RSB
  module Entitlements
    class InstallGenerator < Rails::Generators::Base
      namespace 'rsb:entitlements:install'
      source_root File.expand_path('templates', __dir__)

      desc 'Install rsb-entitlements: copy migrations.'

      def copy_migrations
        rake 'rsb_entitlements:install:migrations'
      end

      def print_post_install
        say ''
        say 'rsb-entitlements installed successfully!', :green
        say ''
        say 'Next steps:'
        say '  1. rails db:migrate'
        say '  2. Include RSB::Entitlements::Entitleable in any model that needs plan-based features.'
        say ''
      end
    end
  end
end
