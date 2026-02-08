require "test_helper"

class RSB::Auth::CredentialDefinitionTest < ActiveSupport::TestCase
  test "stores all attributes" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :email_password,
      class_name: "RSB::Auth::Credential::EmailPassword",
      authenticatable: true,
      registerable: false,
      label: "Email & Password"
    )

    assert_equal :email_password, defn.key
    assert_equal "RSB::Auth::Credential::EmailPassword", defn.class_name
    assert defn.authenticatable
    refute defn.registerable
    assert_equal "Email & Password", defn.label
  end

  test "key is converted to symbol" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: "oauth",
      class_name: "SomeClass"
    )
    assert_equal :oauth, defn.key
  end

  test "defaults authenticatable to true" do
    defn = RSB::Auth::CredentialDefinition.new(key: :test, class_name: "TestClass")
    assert defn.authenticatable
  end

  test "defaults registerable to true" do
    defn = RSB::Auth::CredentialDefinition.new(key: :test, class_name: "TestClass")
    assert defn.registerable
  end

  test "label defaults to titleized key" do
    defn = RSB::Auth::CredentialDefinition.new(key: :email_password, class_name: "TestClass")
    assert_equal "Email Password", defn.label
  end

  test "valid? returns true when key and class_name are present" do
    defn = RSB::Auth::CredentialDefinition.new(key: :test, class_name: "TestClass")
    assert defn.valid?
  end

  test "valid? returns false when key is blank" do
    defn = RSB::Auth::CredentialDefinition.new(key: "", class_name: "TestClass")
    refute defn.valid?
  end

  test "valid? returns false when class_name is blank" do
    defn = RSB::Auth::CredentialDefinition.new(key: :test, class_name: "")
    refute defn.valid?
  end

  test "credential_class constantizes the class_name" do
    defn = RSB::Auth::CredentialDefinition.new(
      key: :test,
      class_name: "RSB::Auth::CredentialDefinition"
    )
    assert_equal RSB::Auth::CredentialDefinition, defn.credential_class
  end
end
