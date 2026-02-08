require "test_helper"

class GenericResourcesTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    # Register TestPost as a generic resource (no custom controller)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, icon: "file", label: "Test Posts", actions: [:index, :show, :new, :create, :edit, :update, :destroy]
    end
  end

  # --- Pagination ---

  test "index paginates records at 25 per page (default)" do
    30.times do |i|
      TestPost.create!(
        title: "Post #{i}",
        body: "Body content #{i}",
        status: "draft"
      )
    end

    get "/admin/test_posts"
    assert_response :success
    assert_match "Next", response.body
    refute_match "Previous", response.body
  end

  test "index page 2 shows remaining records and Previous link" do
    30.times do |i|
      TestPost.create!(
        title: "Post #{i}",
        body: "Body content #{i}",
        status: "draft"
      )
    end

    get "/admin/test_posts?page=2"
    assert_response :success
    assert_match "Previous", response.body
  end

  # --- Edit / Update ---

  test "edit renders form for a generic resource" do
    post = TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft"
    )

    get "/admin/test_posts/#{post.id}/edit"
    assert_response :success
    assert_match "Edit Test Post", response.body
    assert_match 'form', response.body
  end

  test "update persists changes and redirects to show" do
    post = TestPost.create!(
      title: "Original Title",
      body: "Original body",
      status: "draft"
    )

    patch "/admin/test_posts/#{post.id}", params: {
      test_post: { title: "Updated Title" }
    }
    assert_redirected_to "/admin/test_posts/#{post.id}"
    assert_equal "Updated Title", post.reload.title
  end

  test "update with invalid data re-renders edit form" do
    post = TestPost.create!(
      title: "Valid Title",
      body: "Valid body",
      status: "draft"
    )

    # title is required (null: false in migration)
    patch "/admin/test_posts/#{post.id}", params: {
      test_post: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "destroy deletes record and redirects to index" do
    post = TestPost.create!(
      title: "To Delete",
      body: "Will be deleted",
      status: "draft"
    )

    assert_difference "TestPost.count", -1 do
      delete "/admin/test_posts/#{post.id}"
    end
    assert_redirected_to "/admin/test_posts"
  end

  test "show page has danger zone when destroy is registered" do
    post = TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft"
    )

    get "/admin/test_posts/#{post.id}"
    assert_response :success
    assert_match(/Danger Zone/i, response.body)
  end

  test "show page has no danger zone when destroy is not registered" do
    # Re-register without :destroy action
    RSB::Admin.reset!
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, icon: "file", label: "Test Posts", actions: [:index, :show]
    end

    # Re-sign in after reset
    sign_in_admin(@admin)

    post = TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft"
    )

    get "/admin/test_posts/#{post.id}"
    assert_response :success
    refute_match(/Danger Zone/i, response.body)
  end

  # --- Sensitive Columns ---

  test "index excludes sensitive columns" do
    TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft",
      token: "secret-token-value"
    )

    get "/admin/test_posts"
    assert_response :success
    refute_match "secret-token-value", response.body
  end

  test "show excludes sensitive columns" do
    post = TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft",
      token: "secret-token-value"
    )

    get "/admin/test_posts/#{post.id}"
    assert_response :success
    refute_match "secret-token-value", response.body
    assert_match "Test Post", response.body
  end

  test "edit form excludes sensitive columns" do
    post = TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft",
      token: "secret-token-value"
    )

    get "/admin/test_posts/#{post.id}/edit"
    assert_response :success
    refute_match 'test_post[token]', response.body
  end

  # --- Empty State ---

  test "index with no records shows empty state" do
    get "/admin/test_posts"
    assert_response :success
    assert_match(/No test posts found/i, response.body)
  end

  # --- Badge Rendering ---

  test "index renders status as badge" do
    TestPost.create!(
      title: "Active Post",
      body: "Test body",
      status: "active"
    )

    get "/admin/test_posts"
    assert_response :success
    assert_match "bg-rsb-success-bg", response.body
  end

  # --- Index Column Filtering ---

  test "index excludes created_at and updated_at columns" do
    TestPost.create!(
      title: "Test Post",
      body: "Test body",
      status: "draft"
    )

    get "/admin/test_posts"
    assert_response :success
    refute_match "Created at", response.body
    refute_match "Updated at", response.body
  end
end
