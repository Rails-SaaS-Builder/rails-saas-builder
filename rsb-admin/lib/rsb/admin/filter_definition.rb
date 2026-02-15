# frozen_string_literal: true

module RSB
  module Admin
    # Represents a filter definition for admin resource queries.
    #
    # FilterDefinition is an immutable data structure that describes how to filter
    # an ActiveRecord relation. It supports multiple filter types (text, select,
    # boolean, date ranges, number ranges) and can use custom scopes or default
    # filtering logic.
    #
    # @!attribute [r] key
    #   @return [Symbol] the attribute name to filter on
    # @!attribute [r] label
    #   @return [String] the human-readable filter label
    # @!attribute [r] type
    #   @return [Symbol] the filter type (:text, :select, :boolean, :date_range, :number_range)
    # @!attribute [r] options
    #   @return [Array, Proc, nil] options for select filters (array or callable)
    # @!attribute [r] scope
    #   @return [Symbol, Proc, nil] custom scope method name or lambda for filtering
    #
    # @example Building a text filter
    #   filter = FilterDefinition.build(:email)
    #   filter.type #=> :text
    #
    # @example Building a select filter with options
    #   filter = FilterDefinition.build(:status,
    #     type: :select,
    #     options: %w[active suspended banned]
    #   )
    #
    # @example Building a filter with custom scope
    #   filter = FilterDefinition.build(:search,
    #     scope: ->(rel, val) { rel.where("name LIKE ? OR email LIKE ?", "%#{val}%", "%#{val}%") }
    #   )
    FilterDefinition = Data.define(
      :key,      # Symbol
      :label,    # String
      :type,     # Symbol — :text, :select, :boolean, :date_range, :number_range
      :options,  # Array | Proc | nil
      :scope     # Symbol | Proc | nil
    )

    class FilterDefinition
      # Build a FilterDefinition with smart defaults.
      #
      # @param key [Symbol, String] the attribute name to filter
      # @param label [String, nil] the display label (defaults to humanized key)
      # @param type [Symbol] the filter type (default: :text)
      # @param options [Array, Proc, nil] options for select-type filters
      # @param scope [Symbol, Proc, nil] custom filtering logic
      # @return [FilterDefinition] a frozen, immutable filter definition
      #
      # @example
      #   FilterDefinition.build(:created_at, type: :date_range)
      def self.build(key, label: nil, type: :text, options: nil, scope: nil)
        new(
          key: key.to_sym,
          label: label || key.to_s.humanize,
          type: type.to_sym,
          options: options,
          scope: scope
        )
      end

      # Apply this filter to an ActiveRecord relation.
      #
      # If the filter has a custom scope (Proc or Symbol), it will be used.
      # Otherwise, default filtering logic based on the filter type will be applied.
      #
      # @param relation [ActiveRecord::Relation] the relation to filter
      # @param value [Object] the filter value (ignored if blank)
      # @return [ActiveRecord::Relation] the filtered relation
      #
      # @example Applying a text filter
      #   filter = FilterDefinition.build(:email, type: :text)
      #   filtered = filter.apply(User.all, "john")
      #   # Generates: WHERE email LIKE '%john%'
      #
      # @example Applying with blank value (no-op)
      #   filter.apply(User.all, "") #=> returns User.all unchanged
      def apply(relation, value)
        return relation if value.blank?

        if scope.is_a?(Proc)
          scope.call(relation, value)
        elsif scope.is_a?(Symbol)
          relation.send(scope, value)
        else
          apply_default_scope(relation, value)
        end
      end

      private

      # Apply default filtering logic based on the filter type.
      #
      # @param relation [ActiveRecord::Relation] the relation to filter
      # @param value [Object] the filter value
      # @return [ActiveRecord::Relation] the filtered relation
      # @api private
      def apply_default_scope(relation, value)
        case type
        when :text
          relation.where("#{key} LIKE ?", "%#{value}%")
        when :select, :boolean
          relation.where(key => value)
        when :date_range
          from = value[:from]
          to = value[:to]
          scope = relation
          scope = scope.where("#{key} >= ?", from) if from.present?
          scope = scope.where("#{key} <= ?", to) if to.present?
          scope
        when :number_range
          min = value[:min]
          max = value[:max]
          scope = relation
          scope = scope.where("#{key} >= ?", min) if min.present?
          scope = scope.where("#{key} <= ?", max) if max.present?
          scope
        else
          relation.where(key => value)
        end
      end
    end
  end
end
