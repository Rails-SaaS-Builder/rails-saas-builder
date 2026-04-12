# frozen_string_literal: true

module RSB
  module Auth
    module Admin
      class InvitationsController < ::RSB::Admin::AdminController
        before_action :authorize_invitations
        before_action :set_invitation, only: %i[show revoke deliver redeliver extend_expiry]

        def index
          @invitations = RSB::Auth::Invitation.order(created_at: :desc)
          @invitations = apply_filters(@invitations) if params[:q].present?
        end

        def show
          @deliveries = @invitation.deliveries.order(delivered_at: :desc)
          @notifiers = RSB::Auth.notifiers.all
        end

        def new; end

        def create
          service = RSB::Auth::InvitationService.new

          expires_in = if params[:no_expiry] == '1'
                         0 # signals no expiry to InvitationService
                       elsif params[:expires_in_hours].present?
                         params[:expires_in_hours].to_i.hours
                       end
          max_uses = params[:max_uses].present? ? params[:max_uses].to_i : nil
          metadata = params[:metadata].present? ? JSON.parse(params[:metadata]) : {}

          result = service.create(
            label: params[:label],
            max_uses: max_uses,
            expires_in: expires_in,
            metadata: metadata,
            invited_by: current_admin_user
          )

          if result.success?
            redirect_to "/admin/invitations/#{result.invitation.id}", notice: 'Invitation created successfully.'
          else
            flash.now[:alert] = result.error
            render :new, status: :unprocessable_entity
          end
        rescue JSON::ParserError
          flash.now[:alert] = 'Invalid JSON in metadata field.'
          render :new, status: :unprocessable_entity
        end

        def revoke
          @invitation.revoke!
          redirect_to "/admin/invitations/#{@invitation.id}", notice: 'Invitation revoked.'
        end

        def deliver
          service = RSB::Auth::InvitationService.new

          # Build fields hash from notifier form_fields
          channel = params[:channel] || 'email'
          notifier = RSB::Auth.notifiers.find(channel)
          fields = {}
          notifier&.form_fields&.each do |field_def|
            value = params[field_def[:key]]
            fields[field_def[:key]] = value if value.present?
          end

          result = service.deliver(
            @invitation,
            channel: channel,
            fields: fields
          )

          if result.success?
            redirect_to "/admin/invitations/#{@invitation.id}",
                        notice: "Notification sent to #{result.delivery.recipient}."
          else
            redirect_to "/admin/invitations/#{@invitation.id}", alert: result.error
          end
        end

        def redeliver
          delivery = @invitation.deliveries.find(params[:delivery_id])
          service = RSB::Auth::InvitationService.new
          result = service.redeliver(delivery)

          if result.success?
            redirect_to "/admin/invitations/#{@invitation.id}",
                        notice: "Notification resent to #{delivery.recipient}."
          else
            redirect_to "/admin/invitations/#{@invitation.id}", alert: result.error
          end
        end

        def extend_expiry
          service = RSB::Auth::InvitationService.new
          result = service.extend_expiry(@invitation, hours: params[:hours].to_i)

          if result.success?
            redirect_to "/admin/invitations/#{@invitation.id}",
                        notice: "Expiry extended to #{result.invitation.expires_at.strftime('%B %d, %Y at %I:%M %p')}."
          else
            redirect_to "/admin/invitations/#{@invitation.id}", alert: result.error
          end
        end

        private

        def set_invitation
          @invitation = RSB::Auth::Invitation.find(params[:id])
        end

        def authorize_invitations
          authorize_admin_action!(resource: 'invitations', action: action_name)
        end

        def apply_filters(scope)
          filters = params[:q]

          if filters[:status].present?
            scope = case filters[:status]
                    when 'pending' then scope.pending
                    when 'exhausted' then scope.exhausted
                    when 'expired' then scope.expired
                    when 'revoked' then scope.revoked
                    else scope
                    end
          end

          scope = scope.where('label LIKE ?', "%#{filters[:label]}%") if filters[:label].present?

          scope
        end
      end
    end
  end
end
