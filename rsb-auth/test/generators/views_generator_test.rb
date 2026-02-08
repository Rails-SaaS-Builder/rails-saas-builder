# frozen_string_literal: true

require 'test_helper'
require 'generators/rsb/auth/views/views_generator'
require 'rails/generators/test_case'

module RSB
  module Auth
    class ViewsGeneratorTest < Rails::Generators::TestCase
      tests RSB::Auth::ViewsGenerator
      destination File.expand_path('../tmp', __dir__)

      setup do
        prepare_destination
      end

      # --- Export all views ---

      test 'exports all user-facing views when no options given' do
        run_generator

        # Spot-check key files from different groups
        assert_file 'app/views/rsb/auth/sessions/new.html.erb'
        assert_file 'app/views/rsb/auth/registrations/new.html.erb'
        assert_file 'app/views/rsb/auth/account/show.html.erb'
        assert_file 'app/views/rsb/auth/account/_identity_fields.html.erb'
        assert_file 'app/views/rsb/auth/password_resets/new.html.erb'
        assert_file 'app/views/rsb/auth/password_resets/edit.html.erb'
        assert_file 'app/views/rsb/auth/invitations/show.html.erb'
        assert_file 'app/views/rsb/auth/account/confirm_destroy.html.erb'
        assert_file 'app/views/rsb/auth/auth_mailer/verification.html.erb'
        assert_file 'app/views/rsb/auth/auth_mailer/password_reset.html.erb'
        assert_file 'app/views/rsb/auth/auth_mailer/invitation.html.erb'
      end

      test 'does not export admin views' do
        run_generator

        assert_no_file 'app/views/rsb/auth/admin/identities/index.html.erb'
        assert_no_file 'app/views/rsb/auth/admin/identities/show.html.erb'
        assert_no_file 'app/views/rsb/auth/admin/sessions_management/index.html.erb'
      end

      # --- --only filtering ---

      test 'exports only specified groups with --only' do
        run_generator ['--only', 'sessions,registrations']

        assert_file 'app/views/rsb/auth/sessions/new.html.erb'
        assert_file 'app/views/rsb/auth/registrations/new.html.erb'
        assert_no_file 'app/views/rsb/auth/account/show.html.erb'
        assert_no_file 'app/views/rsb/auth/password_resets/new.html.erb'
        assert_no_file 'app/views/rsb/auth/auth_mailer/verification.html.erb'
      end

      test 'exports only account group' do
        run_generator ['--only', 'account']

        assert_file 'app/views/rsb/auth/account/show.html.erb'
        assert_file 'app/views/rsb/auth/account/_identity_fields.html.erb'
        assert_no_file 'app/views/rsb/auth/sessions/new.html.erb'
      end

      test 'exports only mailers group' do
        run_generator ['--only', 'mailers']

        assert_file 'app/views/rsb/auth/auth_mailer/verification.html.erb'
        assert_file 'app/views/rsb/auth/auth_mailer/password_reset.html.erb'
        assert_file 'app/views/rsb/auth/auth_mailer/invitation.html.erb'
        assert_no_file 'app/views/rsb/auth/sessions/new.html.erb'
      end

      test 'exports only layout group' do
        run_generator ['--only', 'layout']

        assert_file 'app/views/layouts/rsb/auth/application.html.erb'
        assert_no_file 'app/views/rsb/auth/sessions/new.html.erb'
      end

      test 'exports only password_resets group' do
        run_generator ['--only', 'password_resets']

        assert_file 'app/views/rsb/auth/password_resets/new.html.erb'
        assert_file 'app/views/rsb/auth/password_resets/edit.html.erb'
        assert_no_file 'app/views/rsb/auth/sessions/new.html.erb'
      end

      # --- Skip/force logic ---

      test 'skips existing files without --force' do
        run_generator ['--only', 'sessions']
        assert_file 'app/views/rsb/auth/sessions/new.html.erb'

        # Run again — should skip
        output = run_generator ['--only', 'sessions']
        assert_match(/skip/, output)
      end

      test 'overwrites existing files with --force' do
        run_generator ['--only', 'sessions']
        file_path = File.join(destination_root, 'app/views/rsb/auth/sessions/new.html.erb')
        File.write(file_path, 'modified content')

        run_generator ['--only', 'sessions', '--force']

        content = File.read(file_path)
        refute_equal 'modified content', content
      end

      # --- Error handling ---

      test 'exits with error for invalid --only group names' do
        assert_raises(SystemExit) do
          run_generator ['--only', 'nonexistent']
        end
      end

      test 'exits with error for partially invalid --only group names' do
        assert_raises(SystemExit) do
          run_generator ['--only', 'sessions,bogus']
        end
      end

      # --- Content verification ---

      test 'exported files have the same content as engine originals' do
        run_generator ['--only', 'sessions']

        source = RSB::Auth::Engine.root.join('app', 'views', 'rsb', 'auth', 'sessions', 'new.html.erb')
        exported = File.join(destination_root, 'app/views/rsb/auth/sessions/new.html.erb')

        assert_equal File.read(source), File.read(exported)
      end

      test 'exported layout has the same content as engine original' do
        run_generator ['--only', 'layout']

        source = RSB::Auth::Engine.root.join('app', 'views', 'layouts', 'rsb', 'auth', 'application.html.erb')
        exported = File.join(destination_root, 'app/views/layouts/rsb/auth/application.html.erb')

        assert_equal File.read(source), File.read(exported)
      end

      # --- Graceful handling of missing source files ---

      test 'skips view files that do not exist in engine' do
        # The verifications/show.html.erb may not exist yet — generator should skip gracefully
        output = run_generator ['--only', 'verifications']
        assert_match(/skip/, output) unless File.exist?(
          RSB::Auth::Engine.root.join('app', 'views', 'rsb', 'auth', 'verifications', 'show.html.erb')
        )
      end
    end
  end
end
