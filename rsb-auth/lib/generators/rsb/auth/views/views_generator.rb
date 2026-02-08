# frozen_string_literal: true

module RSB
  module Auth
    # Generator to export RSB Auth views to the host application for customization.
    #
    # Copies user-facing view files from the RSB Auth engine to the host app's
    # `app/views/rsb/auth/` directory. Rails engine view lookup gives host app
    # views priority over engine defaults, so copied views automatically override
    # engine defaults without additional configuration.
    #
    # Admin views (identity management, sessions management) are NOT included —
    # those are managed by the rsb-admin view generator.
    #
    # @example Export all auth views
    #   rails generate rsb:auth:views
    #
    # @example Export only login and registration views
    #   rails generate rsb:auth:views --only sessions,registrations
    #
    # @example Export mailer templates
    #   rails generate rsb:auth:views --only mailers
    #
    # @example Force overwrite existing files
    #   rails generate rsb:auth:views --force
    #
    class ViewsGenerator < Rails::Generators::Base
      namespace 'rsb:auth:views'
      desc 'Export RSB Auth views to your application for customization.'

      class_option :only, type: :string, default: nil,
                          desc: 'Comma-separated list of view groups to export (sessions,registrations,account,verifications,password_resets,invitations,mailers,layout)'
      class_option :force, type: :boolean, default: false,
                           desc: 'Overwrite existing files'

      # Mapping of view groups to their file paths (relative to the engine views root).
      # Each group corresponds to a controller's view directory.
      # Admin views are intentionally excluded — use rsb:admin:views for those.
      VIEW_GROUPS = {
        'sessions' => [
          'sessions/new.html.erb'
        ],
        'registrations' => [
          'registrations/new.html.erb'
        ],
        'account' => [
          'account/show.html.erb',
          'account/confirm_destroy.html.erb',
          'account/_identity_fields.html.erb'
        ],
        'verifications' => [
          'verifications/show.html.erb'
        ],
        'password_resets' => [
          'password_resets/new.html.erb',
          'password_resets/edit.html.erb'
        ],
        'invitations' => [
          'invitations/show.html.erb'
        ],
        'mailers' => [
          'auth_mailer/verification.html.erb',
          'auth_mailer/password_reset.html.erb',
          'auth_mailer/invitation.html.erb'
        ],
        'layout' => [
          'layouts/rsb/auth/application.html.erb'
        ]
      }.freeze

      # Copies the selected view files from the engine to the host application.
      #
      # Iterates through the selected view groups and copies each file.
      # Existing files are skipped unless --force is used.
      #
      # @return [void]
      def copy_views
        groups = selected_groups

        files_copied = 0
        files_skipped = 0

        groups.each_value do |paths|
          paths.each do |relative_path|
            source = source_path_for(relative_path)
            destination = destination_path_for(relative_path)

            unless File.exist?(source)
              say_status :skip, "#{relative_path} (not found in engine)", :yellow
              next
            end

            if File.exist?(destination) && !options[:force]
              say_status :skip, "#{relative_path} (already exists, use --force to overwrite)", :yellow
              files_skipped += 1
            else
              copy_file_with_status(source, destination)
              files_copied += 1
            end
          end
        end

        say ''
        say "Exported #{files_copied} view(s) to app/views/rsb/auth/", :green
        say "Skipped #{files_skipped} existing file(s)." if files_skipped.positive?
      end

      # Prints instructions about the view override chain.
      #
      # @return [void]
      def print_instructions
        say ''
        say 'View override chain (highest priority first):', :cyan
        say '  1. app/views/rsb/auth/ (your customizations)'
        say '  2. RSB Auth engine defaults (fallback)'
        say ''
        say 'Edit the exported files to customize your auth pages.'
        say "Files you didn't export will continue using engine defaults."
        say ''
      end

      private

      # Returns the filtered set of view groups based on the --only option.
      #
      # When --only is provided, parses the comma-separated list and validates
      # that all group names are recognized. Returns only the matching groups.
      # When --only is not provided, returns all groups.
      #
      # @return [Hash{String => Array<String>}] filtered view groups
      # @raise [SystemExit] if invalid group names are provided
      def selected_groups
        if options[:only]
          keys = options[:only].split(',').map(&:strip)
          invalid = keys - VIEW_GROUPS.keys
          if invalid.any?
            say_status :error,
                       "Unknown view group(s): #{invalid.join(', ')}. Valid groups: #{VIEW_GROUPS.keys.join(', ')}", :red
            exit 1
          end
          VIEW_GROUPS.slice(*keys)
        else
          VIEW_GROUPS
        end
      end

      # Returns the full source path for a given relative view path.
      #
      # Layout files live under app/views/layouts/ (not namespaced),
      # while all other views live under app/views/rsb/auth/.
      #
      # @param relative_path [String] the relative path from VIEW_GROUPS
      # @return [String] absolute path to the source file in the engine
      def source_path_for(relative_path)
        if relative_path.start_with?('layouts/')
          RSB::Auth::Engine.root.join('app', 'views', relative_path).to_s
        else
          File.join(engine_views_root, relative_path)
        end
      end

      # Returns the full destination path for a given relative view path.
      #
      # Layout files go to app/views/layouts/ (not namespaced),
      # while all other views go to app/views/rsb/auth/.
      #
      # @param relative_path [String] the relative path from VIEW_GROUPS
      # @return [String] absolute path to the destination file in the host app
      def destination_path_for(relative_path)
        if relative_path.start_with?('layouts/')
          File.join(destination_root, 'app', 'views', relative_path)
        else
          File.join(destination_root, 'app', 'views', 'rsb', 'auth', relative_path)
        end
      end

      # Returns the engine's namespaced views root directory.
      #
      # @return [String] absolute path to rsb/auth views in the engine
      def engine_views_root
        RSB::Auth::Engine.root.join('app', 'views', 'rsb', 'auth').to_s
      end

      # Copies a file and prints a create status message.
      #
      # @param source [String] absolute path to source file
      # @param destination [String] absolute path to destination file
      # @return [void]
      def copy_file_with_status(source, destination)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
        relative = destination.sub("#{destination_root}/", '')
        say_status :create, relative, :green
      end
    end
  end
end
