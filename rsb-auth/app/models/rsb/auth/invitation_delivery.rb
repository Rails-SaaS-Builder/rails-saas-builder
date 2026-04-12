# frozen_string_literal: true

module RSB
  module Auth
    class InvitationDelivery < ApplicationRecord
      self.table_name = 'rsb_auth_invitation_deliveries'

      belongs_to :invitation, class_name: 'RSB::Auth::Invitation'

      validates :recipient, presence: true
      validates :channel, presence: true
      validates :delivered_at, presence: true
    end
  end
end
