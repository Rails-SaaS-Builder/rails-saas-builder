# frozen_string_literal: true

module RSB
  module Auth
    class InvitationService
      Result = Data.define(:success?, :invitation, :identity, :error)

      def create(email:, invited_by: nil)
        invitation = RSB::Auth::Invitation.create!(email: email, invited_by: invited_by)
        RSB::Auth::AuthMailer.invitation(invitation).deliver_later
        Result.new(success?: true, invitation: invitation, identity: nil, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success?: false, invitation: nil, identity: nil, error: e.record.errors.full_messages.join(', '))
      end

      def accept(token:, password:, password_confirmation:)
        invitation = RSB::Auth::Invitation.pending.find_by(token: token)
        return failure('Invalid or expired invitation.') unless invitation

        credential_type = resolve_credential_type

        ActiveRecord::Base.transaction do
          identity = RSB::Auth::Identity.create!
          identity.credentials.create!(
            type: credential_type,
            identifier: invitation.email,
            password: password,
            password_confirmation: password_confirmation,
            verified_at: Time.current # Invited users are pre-verified
          )
          invitation.accept!
          Result.new(success?: true, invitation: invitation, identity: identity, error: nil)
        end
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages.join(', '))
      end

      private

      def resolve_credential_type
        identifier = RSB::Settings.get('auth.login_identifier')
        definition = RSB::Auth.credentials.for_identifier(identifier)
        raise "No credential type registered for identifier: #{identifier}" unless definition

        definition.class_name
      end

      def failure(error)
        Result.new(success?: false, invitation: nil, identity: nil, error: error)
      end
    end
  end
end
