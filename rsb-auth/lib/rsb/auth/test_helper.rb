module RSB
  module Auth
    module TestHelper
      def self.included(base)
        base.teardown do
          RSB::Auth.reset!
        end
      end

      def create_test_identity(status: :active)
        RSB::Auth::Identity.create!(status: status)
      end

      def create_test_credential(identity:, email: "test@example.com", password: "password1234", verified: true)
        cred = identity.credentials.create!(
          type: "RSB::Auth::Credential::EmailPassword",
          identifier: email,
          password: password,
          password_confirmation: password
        )
        cred.update_column(:verified_at, Time.current) if verified
        cred
      end

      def sign_in_identity(identity)
        session = RSB::Auth::SessionService.new.create(
          identity: identity,
          ip_address: "127.0.0.1",
          user_agent: "TestBrowser/1.0"
        )
        cookies.signed[:rsb_session_token] = session.token if respond_to?(:cookies)
        session
      end

      def register_auth_settings
        RSB::Settings.registry.register(RSB::Auth.settings_schema)
      end

      def register_auth_credentials
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :email_password,
            class_name: "RSB::Auth::Credential::EmailPassword",
            authenticatable: true,
            registerable: true,
            label: "Email & Password",
            icon: "mail",
            form_partial: "rsb/auth/credentials/email_password",
            admin_form_partial: "rsb/auth/admin/credentials/email_password"
          )
        )
      end

      def register_all_auth_credentials
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :email_password,
            class_name: "RSB::Auth::Credential::EmailPassword",
            authenticatable: true,
            registerable: true,
            label: "Email & Password",
            icon: "mail",
            form_partial: "rsb/auth/credentials/email_password",
            admin_form_partial: "rsb/auth/admin/credentials/email_password"
          )
        )
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :username_password,
            class_name: "RSB::Auth::Credential::UsernamePassword",
            authenticatable: true,
            registerable: true,
            label: "Username & Password",
            icon: "user",
            form_partial: "rsb/auth/credentials/username_password",
            admin_form_partial: "rsb/auth/admin/credentials/username_password"
          )
        )
      end

      # Temporarily applies identity concerns for the duration of the block.
      #
      # Prepends each concern onto Identity so they can override model methods
      # (e.g. +complete?+). After the block, methods defined by the concerns
      # are removed from the modules so they do not affect later tests. Ruby
      # cannot un-include a module; use unique anonymous modules per test when
      # reusing the same concern logic across tests.
      #
      # @param concerns [Array<Module>] concern modules to apply
      # @yield block during which concerns are active
      #
      # @example
      #   with_identity_concerns(HasProfile) do
      #     identity = RSB::Auth::Identity.create!
      #     assert identity.respond_to?(:profile)
      #   end
      #
      def with_identity_concerns(*concerns, &block)
        concerns.each do |c|
          RSB::Auth::Identity.prepend(c) unless RSB::Auth::Identity.ancestors.include?(c)
        end
        block.call
      ensure
        concerns.each do |c|
          c.instance_methods(false).each { |m| c.remove_method(m) }
        end
      end

      # Temporarily applies credential concerns for the duration of the block.
      #
      # Includes each concern into the base Credential class. All STI subtypes
      # inherit the concern methods. After the block, methods defined by the
      # concerns are removed so they do not affect later tests. Use unique
      # anonymous modules per test when reusing the same concern across tests.
      #
      # @param concerns [Array<Module>] concern modules to apply
      # @yield block during which concerns are active
      #
      # @example
      #   with_credential_concerns(HasTenant) do
      #     cred = identity.credentials.first
      #     assert cred.respond_to?(:tenant_id)
      #   end
      #
      def with_credential_concerns(*concerns, &block)
        concerns.each do |c|
          RSB::Auth::Credential.include(c) unless RSB::Auth::Credential.ancestors.include?(c)
        end
        block.call
      ensure
        concerns.each do |c|
          c.instance_methods(false).each { |m| c.remove_method(m) }
        end
      end
    end
  end
end
