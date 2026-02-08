require "test_helper"

class IconsModuleTest < ActiveSupport::TestCase
  test "render returns SVG for known icon" do
    svg = RSB::Admin::Icons.render("users")
    assert svg.present?
    assert_includes svg, "<svg"
    assert_includes svg, "currentColor"
  end

  test "render replaces SIZE with provided size" do
    svg = RSB::Admin::Icons.render("users", size: 24)
    assert_includes svg, 'width="24"'
    assert_includes svg, 'height="24"'
  end

  test "render defaults to size 18" do
    svg = RSB::Admin::Icons.render("users")
    assert_includes svg, 'width="18"'
    assert_includes svg, 'height="18"'
  end

  test "render returns empty string for unknown icon" do
    svg = RSB::Admin::Icons.render("nonexistent")
    assert_equal "", svg
  end

  test "render returns html_safe string" do
    svg = RSB::Admin::Icons.render("users")
    assert svg.html_safe?
  end

  test "all bundled icons render valid SVG" do
    RSB::Admin::Icons::ICONS.each_key do |name|
      svg = RSB::Admin::Icons.render(name)
      assert svg.present?, "Icon '#{name}' should render SVG"
      assert_includes svg, "<svg", "Icon '#{name}' should contain <svg tag"
    end
  end

  test "RSB::Admin.icon convenience method works" do
    svg = RSB::Admin.icon("users", size: 20)
    assert svg.present?
    assert_includes svg, 'width="20"'
  end
end

class IconsHelperTest < ActiveSupport::TestCase
  include RSB::Admin::IconsHelper

  test "rsb_admin_icon renders icon with css_class" do
    svg = rsb_admin_icon("users", css_class: "icon-lg")
    assert_includes svg, 'class="icon-lg"'
    assert_includes svg, "<svg"
  end

  test "rsb_admin_icon returns empty string for nonexistent icon" do
    svg = rsb_admin_icon("nonexistent")
    assert_equal "", svg
  end

  test "rsb_admin_icon escapes XSS in css_class" do
    svg = rsb_admin_icon("users", css_class: '"><script>alert("xss")</script>')
    assert_includes svg, '&quot;&gt;&lt;script&gt;'
    refute_includes svg, '<script>'
  end

  test "rsb_admin_icon works without css_class" do
    svg = rsb_admin_icon("users")
    assert svg.present?
    assert_includes svg, "<svg"
    refute_includes svg, 'class='
  end

  test "rsb_admin_icon respects size parameter" do
    svg = rsb_admin_icon("home", size: 32)
    assert_includes svg, 'width="32"'
    assert_includes svg, 'height="32"'
  end
end
