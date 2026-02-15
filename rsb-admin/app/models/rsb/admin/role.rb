# frozen_string_literal: true

module RSB
  module Admin
    class Role < ApplicationRecord
      has_many :admin_users, dependent: :restrict_with_error

      validates :name, presence: true, uniqueness: true
      # Permissions column has a database default of {}, so it's never nil in practice
      # Empty permissions hash is valid (role with no access to anything)

      # Accept permissions as JSON string from forms (legacy)
      def permissions_json=(json_string)
        self.permissions = JSON.parse(json_string)
      rescue JSON::ParserError
        errors.add(:permissions, 'is not valid JSON')
      end

      # Accept permissions from checkbox form params
      # Expected format: { "rsb_auth_identities" => ["index", "show"], "plans" => ["index"] }
      def permissions_checkboxes=(checkbox_params)
        self.permissions = if checkbox_params.blank?
                             {}
                           else
                             # checkbox_params comes as ActionController::Parameters or Hash
                             # Filter out the dummy field (used to ensure param is always sent)
                             checkbox_params.to_h
                                            .reject { |key, _| key.to_s == '_dummy' }
                                            .transform_values do |actions|
                                              Array(actions).map(&:to_s).reject(&:blank?)
                                            end
                                            .reject { |_, actions| actions.empty? }
                           end
      end

      # Set superadmin permissions when toggle is "1"
      def superadmin_toggle=(value)
        return unless ['1', true].include?(value)

        self.permissions = { '*' => ['*'] }
      end

      # Permissions format:
      # {
      #   "identities" => ["index", "show"],
      #   "plans" => ["index", "show", "new", "create", "edit", "update"],
      #   "settings" => ["index", "update"],
      #   "*" => ["*"]  # superadmin
      # }

      def can?(resource, action)
        return true if superadmin?

        allowed = permissions[resource.to_s] || []
        allowed.include?(action.to_s) || allowed.include?('*')
      end

      def superadmin?
        permissions['*']&.include?('*') || false
      end
    end
  end
end
