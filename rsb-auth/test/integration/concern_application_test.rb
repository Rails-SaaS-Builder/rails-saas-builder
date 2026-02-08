# frozen_string_literal: true

require "test_helper"

# Integration tests that verify the engine boot path: concerns registered in
# RSB::Auth.configuration are applied to Identity and Credential when
# to_prepare runs (via Rails.application.reloader.prepare!), without
# manually calling include/prepend.
class ConcernApplicationTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_auth_settings
    register_auth_credentials
    Rails.cache.clear
  end

  teardown do
    # Neutralize concerns applied during this test. Ruby cannot un-prepend,
    # but removing the methods makes them transparent in the MRO.
    @_test_concerns&.each do |concern|
      concern.instance_methods(false).each { |m| concern.remove_method(m) }
    end
  end

  # --- Identity concerns via to_prepare ---

  test "identity concern registered in configuration is applied after to_prepare" do
    concern = Module.new do
      extend ActiveSupport::Concern
      def integration_test_method
        "applied"
      end
    end

    RSB::Auth.configuration.identity_concerns << concern
    trigger_to_prepare

    identity = RSB::Auth::Identity.create!
    assert_equal "applied", identity.integration_test_method
  end

  test "identity concern overrides complete? through engine boot path" do
    concern = Module.new do
      extend ActiveSupport::Concern
      def complete?
        metadata["first_name"].present?
      end
    end

    RSB::Auth.configuration.identity_concerns << concern
    trigger_to_prepare

    incomplete = RSB::Auth::Identity.create!(metadata: {})
    assert_not incomplete.complete?

    complete = RSB::Auth::Identity.create!(metadata: { "first_name" => "Alice" })
    assert complete.complete?
  end

  test "multiple identity concerns applied in order — last override wins" do
    concern_a = Module.new do
      extend ActiveSupport::Concern
      def complete?
        false
      end
    end

    concern_b = Module.new do
      extend ActiveSupport::Concern
      def complete?
        true
      end
    end

    RSB::Auth.configuration.identity_concerns << concern_a
    RSB::Auth.configuration.identity_concerns << concern_b
    trigger_to_prepare

    identity = RSB::Auth::Identity.create!
    assert identity.complete?
  end

  # --- Credential concerns via to_prepare ---

  test "credential concern registered in configuration is applied after to_prepare" do
    concern = Module.new do
      extend ActiveSupport::Concern
      def credential_integration_method
        "applied"
      end
    end

    RSB::Auth.configuration.credential_concerns << concern
    trigger_to_prepare

    identity = RSB::Auth::Identity.create!
    cred = identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "concern-integration@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    assert_equal "applied", cred.credential_integration_method
  end

  test "credential concern is inherited by STI subtypes via to_prepare" do
    concern = Module.new do
      extend ActiveSupport::Concern
      def sti_integration_method
        "inherited"
      end
    end

    RSB::Auth.configuration.credential_concerns << concern
    trigger_to_prepare

    identity = RSB::Auth::Identity.create!
    email_cred = identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "sti-integration@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
    assert_equal "inherited", email_cred.sti_integration_method
    assert_kind_of RSB::Auth::Credential::EmailPassword, email_cred
  end

  # --- Metadata accessor concern (Flow 3 from RFC) ---

  test "concern-based metadata accessors work end-to-end" do
    concern = Module.new do
      extend ActiveSupport::Concern
      def first_name
        metadata["first_name"]
      end

      def first_name=(val)
        metadata["first_name"] = val
      end

      def complete?
        first_name.present?
      end
    end

    RSB::Auth.configuration.identity_concerns << concern
    trigger_to_prepare

    identity = RSB::Auth::Identity.create!(metadata: {})
    assert_not identity.complete?
    assert_nil identity.first_name

    identity.first_name = "Alice"
    identity.save!
    assert_equal "Alice", identity.reload.first_name
    assert identity.complete?
  end

  # --- Default behavior without concerns ---

  test "identity complete? returns true when no concerns registered" do
    identity = RSB::Auth::Identity.create!
    assert identity.complete?
  end

  private

  # Simulates the Rails to_prepare cycle that the engine initializer hooks into.
  # In a real app this runs on every request (development) or once (production).
  # Also tracks applied concerns so teardown can clean them up.
  def trigger_to_prepare
    @_test_concerns = RSB::Auth.configuration.identity_concerns +
                      RSB::Auth.configuration.credential_concerns
    Rails.application.reloader.prepare!
  end

  def default_url_options
    { host: "localhost" }
  end
end
