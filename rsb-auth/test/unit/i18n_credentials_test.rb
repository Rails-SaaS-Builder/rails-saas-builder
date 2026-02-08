require "test_helper"

class RSB::Auth::I18nCredentialsTest < ActiveSupport::TestCase
  test "credential revocation i18n keys are defined" do
    assert_equal "Revoked", I18n.t("rsb.auth.credentials.revoked")
    assert_equal "Active", I18n.t("rsb.auth.credentials.active")
    assert_equal "Credential revoked.", I18n.t("rsb.auth.credentials.revoked_notice")
    assert_equal "Credential restored.", I18n.t("rsb.auth.credentials.restored_notice")
  end

  test "credential revocation confirmation strings are defined" do
    revoke_confirm = I18n.t("rsb.auth.credentials.revoke_confirm")
    assert_includes revoke_confirm, "revoke this credential"

    restore_confirm = I18n.t("rsb.auth.credentials.restore_confirm")
    assert_includes restore_confirm, "Restore"
  end

  test "credential restore conflict message is defined" do
    conflict = I18n.t("rsb.auth.credentials.restore_conflict")
    assert_includes conflict, "Cannot restore"
  end
end
