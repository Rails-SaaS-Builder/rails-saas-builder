require "test_helper"

class RSB::Auth::CredentialDefinitionAdminPartialTest < ActiveSupport::TestCase
  test "accepts admin_form_partial attribute" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :email_password,
      class_name: "RSB::Auth::Credential::EmailPassword",
      label: "Email & Password",
      icon: "mail",
      form_partial: "rsb/auth/credentials/email_password",
      admin_form_partial: "rsb/auth/admin/credentials/email_password"
    )

    assert_equal "rsb/auth/admin/credentials/email_password", defn.admin_form_partial
  end

  test "defaults admin_form_partial to nil" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :test,
      class_name: "TestClass"
    )

    assert_nil defn.admin_form_partial
  end

  test "backward compat — definitions without admin_form_partial still work" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :email_password,
      class_name: "RSB::Auth::Credential::EmailPassword",
      authenticatable: true,
      registerable: true,
      label: "Email & Password",
      icon: "mail",
      form_partial: "rsb/auth/credentials/email_password"
    )

    assert_equal :email_password, defn.key
    assert defn.valid?
    assert_nil defn.admin_form_partial
  end

  test "admin_form_partial is separate from form_partial" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :email_password,
      class_name: "RSB::Auth::Credential::EmailPassword",
      form_partial: "rsb/auth/credentials/email_password",
      admin_form_partial: "rsb/auth/admin/credentials/email_password"
    )

    assert_equal "rsb/auth/credentials/email_password", defn.form_partial
    assert_equal "rsb/auth/admin/credentials/email_password", defn.admin_form_partial
    refute_equal defn.form_partial, defn.admin_form_partial
  end

  test "types without admin_form_partial can be filtered out" do
    with_partial = RSB::Auth::CredentialDefinition.new(
      key: :email_password,
      class_name: "RSB::Auth::Credential::EmailPassword",
      admin_form_partial: "rsb/auth/admin/credentials/email_password"
    )

    without_partial = RSB::Auth::CredentialDefinition.new(
      key: :oauth,
      class_name: "SomeOAuthClass"
    )

    all = [with_partial, without_partial]
    with_admin = all.select(&:admin_form_partial)

    assert_equal 1, with_admin.size
    assert_equal :email_password, with_admin.first.key
  end
end
