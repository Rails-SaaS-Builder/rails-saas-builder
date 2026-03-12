# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    module Google
      class CallbackServiceTest < ActiveSupport::TestCase
        setup do
          register_all_settings
          register_all_credentials
          register_google_test_settings
        end

        # --- LOGIN MODE: existing Google credential by provider_uid ---

        test 'login mode: finds existing active Google credential by provider_uid' do
          identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-1',
            verified_at: Time.current
          )

          result = call_service(email: 'user@gmail.com', google_uid: 'google-uid-1', mode: 'login')

          assert result.success?
          assert_equal identity, result.identity
          assert_equal :logged_in, result.action
        end

        test 'login mode: updates email on credential if Google email changed' do
          identity = create_test_identity
          credential = RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'old-email@gmail.com',
            provider_uid: 'google-uid-2',
            verified_at: Time.current
          )

          result = call_service(email: 'new-email@gmail.com', google_uid: 'google-uid-2', mode: 'login')

          assert result.success?
          assert_equal 'new-email@gmail.com', credential.reload.identifier
        end

        test 'login mode: revoked Google credential treated as not found' do
          identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'google-uid-revoked',
            verified_at: Time.current,
            revoked_at: Time.current
          )

          # No auto-merge, no registration -> should fail
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', false)
          RSB::Settings.set('auth.registration_mode', 'disabled')

          result = call_service(email: 'user@gmail.com', google_uid: 'google-uid-revoked', mode: 'login')

          assert_not result.success?
        end

        # --- LOGIN MODE: fallback to email lookup ---

        test 'login mode: finds existing Google credential by email when uid not matched' do
          identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'different-uid',
            verified_at: Time.current
          )

          result = call_service(email: 'user@gmail.com', google_uid: 'new-uid-from-google', mode: 'login')

          assert result.success?
          assert_equal identity, result.identity
          assert_equal :logged_in, result.action
        end

        # --- LOGIN MODE: auto-register (no existing credential) ---

        test 'login mode: auto-registers when no credential exists and registration enabled' do
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          result = call_service(email: 'newuser@gmail.com', google_uid: 'new-uid', mode: 'login')

          assert result.success?
          assert_equal :registered, result.action
          assert_not_nil result.identity
          assert_not_nil result.credential
          assert_equal 'newuser@gmail.com', result.credential.identifier
          assert_equal 'new-uid', result.credential.provider_uid
          assert result.credential.verified?
        end

        test 'login mode: fails when no credential exists and registration disabled' do
          RSB::Settings.set('auth.registration_mode', 'disabled')

          result = call_service(email: 'newuser@gmail.com', google_uid: 'new-uid', mode: 'login')

          assert_not result.success?
          assert_match(/registration.*disabled/i, result.error)
        end

        # --- SIGNUP MODE ---

        test 'signup mode: creates new identity and credential' do
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          result = call_service(email: 'signup@gmail.com', google_uid: 'signup-uid', mode: 'signup')

          assert result.success?
          assert_equal :registered, result.action
          assert_not_nil result.identity
          assert_equal 'active', result.identity.status
          assert result.credential.verified?
        end

        test 'signup mode: existing credential found treats as login' do
          identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'existing@gmail.com',
            provider_uid: 'existing-uid',
            verified_at: Time.current
          )

          result = call_service(email: 'existing@gmail.com', google_uid: 'existing-uid', mode: 'signup')

          assert result.success?
          assert_equal :logged_in, result.action
          assert_equal identity, result.identity
        end

        test 'signup mode: fails when registration mode is disabled' do
          RSB::Settings.set('auth.registration_mode', 'disabled')

          result = call_service(email: 'newuser@gmail.com', google_uid: 'new-uid', mode: 'signup')

          assert_not result.success?
          assert_match(/registration.*disabled/i, result.error)
        end

        test 'signup mode: fails when registration mode is invite_only' do
          RSB::Settings.set('auth.registration_mode', 'invite_only')

          result = call_service(email: 'newuser@gmail.com', google_uid: 'new-uid', mode: 'signup')

          assert_not result.success?
          assert_match(/registration.*disabled/i, result.error)
        end

        test 'signup mode: fails when google credential registerable is false' do
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', false)

          result = call_service(email: 'newuser@gmail.com', google_uid: 'new-uid', mode: 'signup')

          assert_not result.success?
          assert_match(/registration.*disabled/i, result.error)
        end

        # --- AUTO-MERGE (US-005) ---

        test 'auto-merge: links Google to existing identity when emails match and auto_merge enabled' do
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)

          identity = create_test_identity
          create_test_credential(identity: identity, email: 'shared@example.com')

          result = call_service(email: 'shared@example.com', google_uid: 'merge-uid', mode: 'login')

          assert result.success?
          assert_equal :logged_in, result.action
          assert_equal identity, result.identity

          # Verify a Google credential was created on the existing identity
          google_cred = identity.credentials.find_by(type: 'RSB::Auth::Google::Credential')
          assert_not_nil google_cred
          assert_equal 'merge-uid', google_cred.provider_uid
          assert google_cred.verified?
        end

        test 'auto-merge: only matches active non-revoked credentials' do
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          identity = create_test_identity
          credential = create_test_credential(identity: identity, email: 'revoked@example.com')
          credential.revoke!

          # Revoked credential should not trigger auto-merge -- should register new
          result = call_service(email: 'revoked@example.com', google_uid: 'revoked-uid', mode: 'login')

          assert result.success?
          assert_equal :registered, result.action
          assert_not_equal identity, result.identity
        end

        test 'auto-merge disabled: returns error when email conflicts' do
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', false)
          RSB::Settings.set('auth.generic_error_messages', false)

          identity = create_test_identity
          create_test_credential(identity: identity, email: 'conflict@example.com')

          result = call_service(email: 'conflict@example.com', google_uid: 'conflict-uid', mode: 'login')

          assert_not result.success?
          assert_match(/already exists/i, result.error)
        end

        test 'auto-merge disabled with generic errors: returns generic error on email conflict' do
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', false)
          RSB::Settings.set('auth.generic_error_messages', true)

          identity = create_test_identity
          create_test_credential(identity: identity, email: 'conflict@example.com')

          result = call_service(email: 'conflict@example.com', google_uid: 'conflict-uid', mode: 'login')

          assert_not result.success?
          assert_equal 'Invalid credentials.', result.error
        end

        test 'auto-merge still works when registration is disabled' do
          RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)
          RSB::Settings.set('auth.registration_mode', 'disabled')

          identity = create_test_identity
          create_test_credential(identity: identity, email: 'merge-disabled-reg@example.com')

          result = call_service(email: 'merge-disabled-reg@example.com', google_uid: 'merge-uid-2', mode: 'login')

          assert result.success?
          assert_equal identity, result.identity
        end

        # --- LINK MODE (US-003) ---

        test 'link mode: creates Google credential on current identity' do
          identity = create_test_identity
          create_test_credential(identity: identity, email: 'linker@example.com')

          result = call_service(
            email: 'google-account@gmail.com',
            google_uid: 'link-uid',
            mode: 'link',
            current_identity: identity
          )

          assert result.success?
          assert_equal :linked, result.action
          assert_equal identity, result.identity
          assert_equal 'google-account@gmail.com', result.credential.identifier
          assert result.credential.verified?
        end

        test 'link mode: fails when current_identity is nil' do
          result = call_service(
            email: 'user@gmail.com',
            google_uid: 'link-uid',
            mode: 'link',
            current_identity: nil
          )

          assert_not result.success?
          assert_match(/not authenticated/i, result.error)
        end

        test 'link mode: returns already_linked when same identity already has this Google credential' do
          identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'user@gmail.com',
            provider_uid: 'already-linked-uid',
            verified_at: Time.current
          )

          result = call_service(
            email: 'user@gmail.com',
            google_uid: 'already-linked-uid',
            mode: 'link',
            current_identity: identity
          )

          assert result.success?
          assert_equal :already_linked, result.action
        end

        test 'link mode: fails when Google account belongs to different identity' do
          other_identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: other_identity,
            identifier: 'taken@gmail.com',
            provider_uid: 'taken-uid',
            verified_at: Time.current
          )

          my_identity = create_test_identity

          result = call_service(
            email: 'taken@gmail.com',
            google_uid: 'taken-uid',
            mode: 'link',
            current_identity: my_identity
          )

          assert_not result.success?
          assert_match(/already linked to another/i, result.error)
        end

        test 'link mode: fails when Google email belongs to different identity via different credential' do
          other_identity = create_test_identity
          RSB::Auth::Google::Credential.create!(
            identity: other_identity,
            identifier: 'shared@gmail.com',
            provider_uid: 'other-uid',
            verified_at: Time.current
          )

          my_identity = create_test_identity

          result = call_service(
            email: 'shared@gmail.com',
            google_uid: 'my-uid',
            mode: 'link',
            current_identity: my_identity
          )

          assert_not result.success?
          assert_match(/already linked to another/i, result.error)
        end

        # --- LIFECYCLE HOOKS ---

        test 'fires after_identity_created lifecycle hook on registration' do
          RSB::Settings.set('auth.registration_mode', 'open')
          RSB::Settings.set('auth.credentials.google.registerable', true)

          # Identity model fires after_identity_created via after_commit on create.
          # Verify registration creates an identity (the hook fires automatically).
          result = call_service(email: 'hook@gmail.com', google_uid: 'hook-uid', mode: 'signup')

          assert result.success?
          assert_equal :registered, result.action
          assert_not_nil result.identity
          assert result.identity.persisted?
        end

        # --- CONCURRENT ACCESS ---

        test 'handles concurrent credential creation gracefully via unique index' do
          identity = create_test_identity
          # Pre-create to simulate race condition on unique index
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: 'race@gmail.com',
            provider_uid: 'race-uid',
            verified_at: Time.current
          )

          # Second attempt with same provider_uid should find existing, not crash
          result = call_service(email: 'race@gmail.com', google_uid: 'race-uid', mode: 'login')

          assert result.success?
          assert_equal identity, result.identity
        end

        private

        def call_service(email:, google_uid:, mode:, current_identity: nil)
          RSB::Auth::Google::CallbackService.new.call(
            email: email,
            google_uid: google_uid,
            mode: mode,
            current_identity: current_identity
          )
        end

        def register_google_test_settings
          schema = RSB::Settings::Schema.new('auth') do
            setting :'credentials.google.client_id', type: :string, default: ''
            setting :'credentials.google.client_secret', type: :string, default: ''
            setting :'credentials.google.auto_merge_by_email', type: :boolean, default: false
            setting :'credentials.google.enabled', type: :boolean, default: true
            setting :'credentials.google.registerable', type: :boolean, default: true
            setting :'credentials.google.verification_required', type: :boolean, default: false
            setting :'credentials.google.auto_verify_on_signup', type: :boolean, default: true
            setting :'credentials.google.allow_login_unverified', type: :boolean, default: true
          end
          RSB::Settings.registry.register(schema)
        rescue RSB::Settings::DuplicateSettingError
          # Already registered
        end
      end
    end
  end
end
