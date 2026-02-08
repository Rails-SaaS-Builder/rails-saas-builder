module RSB
  module Auth
    class CredentialDefinition
      attr_reader :key, :class_name, :authenticatable, :registerable, :label,
                  :icon, :form_partial, :redirect_url, :admin_form_partial

      # @param key [Symbol, String] unique identifier for the credential type
      # @param class_name [String] fully-qualified class name of the credential model
      # @param authenticatable [Boolean] whether this credential can be used to sign in (default: true)
      # @param registerable [Boolean] whether new users can register with this credential (default: true)
      # @param label [String, nil] human-readable label (defaults to titleized key)
      # @param icon [String, nil] icon name for UI display (e.g. "mail", "phone", "user")
      # @param form_partial [String, nil] Rails partial path for the credential's login/register form
      # @param redirect_url [String, nil] redirect URL for OAuth/redirect-based credential flows
      def initialize(key:, class_name:, authenticatable: true, registerable: true, label: nil,
                     icon: nil, form_partial: nil, redirect_url: nil, admin_form_partial: nil)
        @key = key.to_sym
        @class_name = class_name.to_s
        @authenticatable = authenticatable
        @registerable = registerable
        @label = label || key.to_s.titleize
        @icon = icon
        @form_partial = form_partial
        @redirect_url = redirect_url
        @admin_form_partial = admin_form_partial
      end

      def credential_class
        @class_name.constantize
      end

      def valid?
        key.present? && class_name.present?
      end
    end
  end
end
