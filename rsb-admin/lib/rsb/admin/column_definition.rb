module RSB
  module Admin
    # Represents a column definition for admin resource tables.
    #
    # ColumnDefinition is an immutable data structure that describes how a column
    # should be displayed in index and show views. It handles column metadata,
    # formatting, sorting, and visibility rules.
    #
    # @!attribute [r] key
    #   @return [Symbol] the attribute name to display
    # @!attribute [r] label
    #   @return [String] the human-readable column header
    # @!attribute [r] sortable
    #   @return [Boolean] whether the column can be sorted
    # @!attribute [r] formatter
    #   @return [Symbol, Proc, nil] optional formatter for the column value
    # @!attribute [r] link
    #   @return [Boolean] whether to render the value as a link to the resource
    # @!attribute [r] visible_on
    #   @return [Array<Symbol>] contexts where this column is visible (:index, :show)
    #
    # @example Building a simple column
    #   col = ColumnDefinition.build(:email)
    #   col.key        #=> :email
    #   col.label      #=> "Email"
    #   col.sortable   #=> false
    #   col.link       #=> false
    #
    # @example Building an ID column (link defaults to true)
    #   col = ColumnDefinition.build(:id)
    #   col.link #=> true
    #
    # @example Building a custom column with formatter
    #   col = ColumnDefinition.build(:status, 
    #     label: "State", 
    #     sortable: true, 
    #     formatter: :badge,
    #     visible_on: [:index]
    #   )
    ColumnDefinition = Data.define(
      :key,        # Symbol
      :label,      # String
      :sortable,   # Boolean
      :formatter,  # Symbol | Proc | nil
      :link,       # Boolean
      :visible_on  # Array<Symbol>
    )

    class ColumnDefinition
      # Build a ColumnDefinition with smart defaults.
      #
      # @param key [Symbol, String] the attribute name
      # @param label [String, nil] the display label (defaults to humanized key)
      # @param sortable [Boolean] whether the column is sortable (default: false)
      # @param formatter [Symbol, Proc, nil] optional value formatter
      # @param link [Boolean, nil] whether to link the value (default: true for :id, false otherwise)
      # @param visible_on [Symbol, Array<Symbol>] contexts where visible (default: [:index, :show])
      # @return [ColumnDefinition] a frozen, immutable column definition
      #
      # @example
      #   ColumnDefinition.build(:created_at, label: "Created", sortable: true)
      def self.build(key, label: nil, sortable: false, formatter: nil, link: nil, visible_on: [:index, :show])
        new(
          key: key.to_sym,
          label: label || key.to_s.humanize,
          sortable: sortable,
          formatter: formatter,
          link: link.nil? ? (key.to_sym == :id) : link,
          visible_on: Array(visible_on).map(&:to_sym)
        )
      end

      # Check if this column is visible in a given context.
      #
      # @param context [Symbol, String] the rendering context (:index or :show)
      # @return [Boolean] true if the column should be displayed in this context
      #
      # @example
      #   col = ColumnDefinition.build(:email, visible_on: [:index])
      #   col.visible_on?(:index) #=> true
      #   col.visible_on?(:show)  #=> false
      def visible_on?(context)
        visible_on.include?(context.to_sym)
      end
    end
  end
end
