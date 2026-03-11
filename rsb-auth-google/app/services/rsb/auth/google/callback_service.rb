# frozen_string_literal: true

module RSB
  module Auth
    module Google
      # Processes verified Google claims into a credential/identity.
      # Handles three modes: login (find or register), signup (register),
      # and link (add to existing identity).
      #
      # @example
      #   service = RSB::Auth::Google::CallbackService.new
      #   result = service.call(
      #     email: 'user@gmail.com',
      #     google_uid: '118234567890',
      #     mode: 'login',
      #     current_identity: nil
      #   )
      class CallbackService
        Result = Data.define(:success?, :identity, :credential, :error, :action)

        # Processes the Google OAuth callback.
        #
        # @param email [String] verified Google email
        # @param google_uid [String] Google user ID (sub claim)
        # @param mode [String] "login", "signup", or "link"
        # @param current_identity [RSB::Auth::Identity, nil] current identity for link mode
        # @return [CallbackService::Result]
        def call(email:, google_uid:, mode:, current_identity: nil)
          case mode.to_s
          when 'link'
            handle_link(email: email, google_uid: google_uid, current_identity: current_identity)
          when 'signup'
            handle_signup(email: email, google_uid: google_uid)
          else # 'login' or default
            handle_login(email: email, google_uid: google_uid)
          end
        end

        private

        # --- LOGIN MODE ---

        def handle_login(email:, google_uid:)
          # Step 1: Look up by provider_uid (primary lookup)
          credential = find_active_credential_by_uid(google_uid)
          if credential
            update_email_if_changed(credential, email)
            return success(identity: credential.identity, credential: credential, action: :logged_in)
          end

          # Step 2: Look up by email among active Google credentials
          credential = find_active_credential_by_email(email)
          if credential
            return success(identity: credential.identity, credential: credential, action: :logged_in)
          end

          # Step 3: Auto-merge or auto-register
          handle_no_credential(email: email, google_uid: google_uid)
        end

        # --- SIGNUP MODE ---

        def handle_signup(email:, google_uid:)
          # If existing credential found, treat as login
          credential = find_active_credential_by_uid(google_uid) || find_active_credential_by_email(email)
          if credential
            update_email_if_changed(credential, email) if credential.provider_uid == google_uid
            return success(identity: credential.identity, credential: credential, action: :logged_in)
          end

          # Check registration is allowed
          unless registration_allowed?
            return failure('Registration is currently disabled.')
          end

          # Check for email conflict -> auto-merge or error
          handle_no_credential(email: email, google_uid: google_uid)
        end

        # --- LINK MODE ---

        def handle_link(email:, google_uid:, current_identity:)
          unless current_identity
            return failure('Not authenticated. Please log in first.')
          end

          # Check if this Google account is already linked
          existing = find_active_credential_by_uid(google_uid)
          if existing
            if existing.identity_id == current_identity.id
              return success(identity: current_identity, credential: existing, action: :already_linked)
            else
              return failure('This Google account is already linked to another account.')
            end
          end

          # Check if email is linked to different identity via Google credential
          email_match = find_active_credential_by_email(email)
          if email_match && email_match.identity_id != current_identity.id
            return failure('This Google account is already linked to another account.')
          end

          # Create Google credential on current identity
          credential = create_google_credential(
            identity: current_identity,
            email: email,
            google_uid: google_uid
          )

          Rails.logger.info { "#{LOG_TAG} Linked Google credential to identity id=#{current_identity.id}" }
          success(identity: current_identity, credential: credential, action: :linked)
        end

        # --- SHARED LOGIC ---

        def handle_no_credential(email:, google_uid:)
          # Look for any active credential (any type) with the same email
          email_credential = RSB::Auth::Credential.active.find_by(identifier: email)

          if email_credential
            # Email exists on another identity
            return handle_email_conflict(
              email: email,
              google_uid: google_uid,
              existing_identity: email_credential.identity
            )
          end

          # No email match -- register new identity (if allowed)
          register_new_identity(email: email, google_uid: google_uid)
        end

        def handle_email_conflict(email:, google_uid:, existing_identity:)
          auto_merge = RSB::Settings.get('auth.credentials.google.auto_merge_by_email')

          if auto_merge
            # Auto-merge: create Google credential on existing identity
            credential = create_google_credential(
              identity: existing_identity,
              email: email,
              google_uid: google_uid
            )
            Rails.logger.info { "#{LOG_TAG} Auto-merged Google credential to existing identity id=#{existing_identity.id}" }
            return success(identity: existing_identity, credential: credential, action: :logged_in)
          end

          # No auto-merge: return error
          Rails.logger.info { "#{LOG_TAG} Google login blocked: email conflict for #{email}, auto_merge disabled" }

          generic_errors = RSB::Settings.get('auth.generic_error_messages')
          if generic_errors
            failure('Invalid credentials.')
          else
            failure('An account with this email already exists. Please log in with your password and link Google from your account page.')
          end
        end

        def register_new_identity(email:, google_uid:)
          unless registration_allowed?
            return failure('Registration is currently disabled.')
          end

          identity = RSB::Auth::Identity.create!(status: :active)
          credential = create_google_credential(
            identity: identity,
            email: email,
            google_uid: google_uid
          )

          Rails.logger.info { "#{LOG_TAG} Created Google credential for new identity id=#{identity.id}" }

          success(identity: identity, credential: credential, action: :registered)
        end

        def create_google_credential(identity:, email:, google_uid:)
          RSB::Auth::Google::Credential.create!(
            identity: identity,
            identifier: email,
            provider_uid: google_uid,
            verified_at: Time.current
          )
        end

        def find_active_credential_by_uid(google_uid)
          RSB::Auth::Google::Credential.active.find_by(provider_uid: google_uid)
        end

        def find_active_credential_by_email(email)
          RSB::Auth::Google::Credential.active.find_by(identifier: email.downcase)
        end

        def update_email_if_changed(credential, email)
          return if credential.identifier == email.downcase

          credential.update!(identifier: email)
          Rails.logger.info { "#{LOG_TAG} Updated Google credential email to #{email} for identity id=#{credential.identity_id}" }
        end

        def registration_allowed?
          mode = RSB::Settings.get('auth.registration_mode').to_s
          return false if mode == 'disabled' || mode == 'invite_only'

          registerable = RSB::Settings.get('auth.credentials.google.registerable')
          ActiveModel::Type::Boolean.new.cast(registerable)
        end

        def success(identity:, credential:, action:)
          Result.new(success?: true, identity: identity, credential: credential, error: nil, action: action)
        end

        def failure(error)
          Result.new(success?: false, identity: nil, credential: nil, error: error, action: nil)
        end
      end
    end
  end
end
