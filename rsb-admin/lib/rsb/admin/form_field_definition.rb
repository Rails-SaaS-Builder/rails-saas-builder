module RSB
  module Admin
    # Represents a form field definition for admin resource forms.
    #
    # FormFieldDefinition is an immutable data structure that describes how a form
    # field should be rendered and validated in new/edit forms. It handles field
    # type, options, validation, hints, and visibility rules.
    #
    # @!attribute [r] key
    #   @return [Symbol] the attribute name for this field
    # @!attribute [r] label
    #   @return [String] the human-readable field label
    # @!attribute [r] type
    #   @return [Symbol] the field type (:text, :textarea, :select, :checkbox, :number, :email, :password, :datetime, :hidden, :json)
    # @!attribute [r] options
    #   @return [Array, Proc, nil] options for select-type fields (array or callable)
    # @!attribute [r] required
    #   @return [Boolean] whether the field is required
    # @!attribute [r] hint
    #   @return [String, nil] optional help text displayed below the field
    # @!attribute [r] visible_on
    #   @return [Array<Symbol>] contexts where this field is visible (:new, :edit)
    #
    # @example Building a simple text field
    #   field = FormFieldDefinition.build(:name)
    #   field.key       #=> :name
    #   field.label     #=> "Name"
    #   field.type      #=> :text
    #   field.required  #=> false
    #
    # @example Building a required email field
    #   field = FormFieldDefinition.build(:email, 
    #     type: :email, 
    #     required: true, 
    #     hint: "We'll never share your email"
    #   )
    #
    # @example Building a select field with options
    #   field = FormFieldDefinition.build(:role,
    #     type: :select,
    #     options: %w[admin user guest],
    #     required: true
    #   )
    FormFieldDefinition = Data.define(
      :key,        # Symbol
      :label,      # String
      :type,       # Symbol — :text, :textarea, :select, :checkbox, :number, :email, :password, :datetime, :hidden, :json
      :options,    # Array | Proc | nil
      :required,   # Boolean
      :hint,       # String | nil
      :visible_on  # Array<Symbol>
    )

    class FormFieldDefinition
      # Build a FormFieldDefinition with smart defaults.
      #
      # @param key [Symbol, String] the attribute name
      # @param label [String, nil] the display label (defaults to humanized key)
      # @param type [Symbol] the field type (default: :text)
      # @param options [Array, Proc, nil] options for select-type fields
      # @param required [Boolean] whether the field is required (default: false)
      # @param hint [String, nil] optional help text
      # @param visible_on [Symbol, Array<Symbol>] contexts where visible (default: [:new, :edit])
      # @return [FormFieldDefinition] a frozen, immutable form field definition
      #
      # @example
      #   FormFieldDefinition.build(:description, type: :textarea, required: true)
      def self.build(key, label: nil, type: :text, options: nil, required: false, hint: nil, visible_on: [:new, :edit])
        new(
          key: key.to_sym,
          label: label || key.to_s.humanize,
          type: type.to_sym,
          options: options,
          required: required,
          hint: hint,
          visible_on: Array(visible_on).map(&:to_sym)
        )
      end

      # Check if this field is visible in a given context.
      #
      # @param context [Symbol, String] the rendering context (:new or :edit)
      # @return [Boolean] true if the field should be displayed in this context
      #
      # @example
      #   field = FormFieldDefinition.build(:password, visible_on: [:new])
      #   field.visible_on?(:new)  #=> true
      #   field.visible_on?(:edit) #=> false
      def visible_on?(context)
        visible_on.include?(context.to_sym)
      end
    end
  end
end
