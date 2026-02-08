require "test_helper"
require "ostruct"

class TableHelperTest < ActionView::TestCase
  include RSB::Admin::TableHelper

  setup do
    # Mock request and params for testing
    @request = OpenStruct.new(path: "/admin/test_posts")
    @params = {}
  end

  attr_reader :request, :params

  test "sort_link returns URL with sort and dir=asc when no current sort" do
    col = RSB::Admin::ColumnDefinition.build(:title, sortable: true)
    result = sort_link(col)
    
    assert_equal "/admin/test_posts?sort=title&dir=asc", result
  end

  test "sort_link flips direction from asc to desc" do
    @params = { sort: "title", dir: "asc" }
    col = RSB::Admin::ColumnDefinition.build(:title, sortable: true)
    result = sort_link(col)
    
    assert_equal "/admin/test_posts?sort=title&dir=desc", result
  end

  test "sort_link removes sort when direction is already desc (cycles to none)" do
    @params = { sort: "title", dir: "desc" }
    col = RSB::Admin::ColumnDefinition.build(:title, sortable: true)
    result = sort_link(col)
    
    assert_equal "/admin/test_posts", result
  end

  test "sort_link sorts new column when different column already sorted" do
    @params = { sort: "status", dir: "asc" }
    col = RSB::Admin::ColumnDefinition.build(:title, sortable: true)
    result = sort_link(col)
    
    assert_equal "/admin/test_posts?sort=title&dir=asc", result
  end

  test "sort_link preserves existing filter params" do
    @params = { sort: "title", dir: "asc", q: { status: "active", title: "test" } }
    col = RSB::Admin::ColumnDefinition.build(:title, sortable: true)
    result = sort_link(col)
    
    assert_includes result, "sort=title"
    assert_includes result, "dir=desc"
    assert_includes result, "q[status]=active"
    assert_includes result, "q[title]=test"
  end

  test "filter_query_string returns empty string when no filter params" do
    result = filter_query_string
    assert_equal "", result
  end

  test "filter_query_string returns query string when filter params present" do
    @params = { q: { status: "active", title: "test" } }
    result = filter_query_string
    
    assert_includes result, "q[status]=active"
    assert_includes result, "q[title]=test"
  end

  test "filter_query_string handles special characters in filter values" do
    @params = { q: { title: "test & value" } }
    result = filter_query_string
    
    # ERB::Util.url_encode uses %20 for spaces, not +
    assert_includes result, "q[title]=test%20%26%20value"
  end
end
