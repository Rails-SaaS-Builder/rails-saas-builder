# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class I18nAccountKeysTest < ActiveSupport::TestCase
      # Verify all i18n keys used by account views and controllers resolve
      # to non-missing translations.

      REQUIRED_KEYS = %w[
        rsb.auth.account.title
        rsb.auth.account.subtitle
        rsb.auth.account.save
        rsb.auth.account.updated
        rsb.auth.account.disabled
        rsb.auth.account.complete_profile
        rsb.auth.account.login_methods_title
        rsb.auth.account.verified
        rsb.auth.account.unverified
        rsb.auth.account.sessions_title
        rsb.auth.account.current_session
        rsb.auth.account.session_revoked
        rsb.auth.account.all_sessions_revoked
        rsb.auth.account.revoke_all_sessions
        rsb.auth.account.login_method_title
        rsb.auth.account.change_password_title
        rsb.auth.account.password_changed
        rsb.auth.account.no_credential
        rsb.auth.account.cannot_remove_last
        rsb.auth.account.login_method_removed
        rsb.auth.account.remove_login_method
        rsb.auth.account.remove_confirm
        rsb.auth.account.already_verified
        rsb.auth.account.verification_sent
        rsb.auth.account.delete_title
        rsb.auth.account.delete_warning
        rsb.auth.account.delete_button
        rsb.auth.account.delete_confirm
        rsb.auth.account.confirm_destroy_title
        rsb.auth.account.confirm_destroy_subtitle
        rsb.auth.account.deleted
        rsb.auth.account.deletion_disabled
        rsb.auth.account.no_credential_for_delete
      ].freeze

      REQUIRED_KEYS.each do |key|
        test "i18n key #{key} resolves to a string" do
          value = I18n.t(key, raise: true)
          assert_kind_of String, value
          assert value.present?, "Expected #{key} to resolve to a non-blank string"
        end
      end
    end
  end
end
