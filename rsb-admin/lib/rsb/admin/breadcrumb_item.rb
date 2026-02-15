# frozen_string_literal: true

module RSB
  module Admin
    # Represents a breadcrumb item in admin navigation.
    #
    # BreadcrumbItem is an immutable data structure representing a single item
    # in a breadcrumb trail. The path is nil for the current (last) item.
    #
    # @!attribute [r] label
    #   @return [String] the text to display for this breadcrumb
    # @!attribute [r] path
    #   @return [String, nil] the URL path (nil for the current/last item)
    #
    # @example Building a breadcrumb trail
    #   [
    #     BreadcrumbItem.new(label: "Admin", path: "/admin"),
    #     BreadcrumbItem.new(label: "Users", path: "/admin/users"),
    #     BreadcrumbItem.new(label: "John Doe", path: nil) # current page
    #   ]
    BreadcrumbItem = Data.define(
      :label,  # String
      :path    # String | nil — nil for current (last) item
    )
  end
end
