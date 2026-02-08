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
        errors.add(:permissions, "is not valid JSON")
      end

      # Accept permissions from checkbox form params
      # Expected format: { "rsb_auth_identities" => ["index", "show"], "plans" => ["index"] }
      def permissions_checkboxes=(checkbox_params)
        if checkbox_params.blank?
          self.permissions = {}
        else
          # checkbox_params comes as ActionController::Parameters or Hash
          # Filter out the dummy field (used to ensure param is always sent)
          self.permissions = checkbox_params.to_h
            .reject { |key, _| key.to_s == "_dummy" }
            .transform_values { |actions|
              Array(actions).map(&:to_s).reject(&:blank?)
            }
            .reject { |_, actions| actions.empty? }
        end
      end

      # Set superadmin permissions when toggle is "1"
      def superadmin_toggle=(value)
        if value == "1" || value == true
          self.permissions = { "*" => ["*"] }
        end
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
        allowed.include?(action.to_s) || allowed.include?("*")
      end

      def superadmin?
        permissions["*"]&.include?("*") || false
      end
    end
  end
end
