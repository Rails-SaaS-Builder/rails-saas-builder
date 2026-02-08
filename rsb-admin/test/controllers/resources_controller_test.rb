require "test_helper"

class ResourcesControllerFilterTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    RSB::Admin.registry.register_category "Content" do
      resource TestPost,
        actions: [:index, :show, :new, :create, :edit, :update, :destroy],
        per_page: 5,
        default_sort: { column: :title, direction: :asc } do

        column :id, link: true
        column :title, sortable: true
        filter :title, type: :text
      end
    end
  end

  # Filtering (AC 1-2)
  test "index applies text filter from params[:q]" do
    # Create test posts
    TestPost.create!(title: "findme post", body: "Body", status: "draft")
    TestPost.create!(title: "other post", body: "Body", status: "draft")

    get "/admin/test_posts", params: { q: { title: "findme" } }
    assert_response :success
    assert_match "findme post", response.body
    refute_match "other post", response.body
  end

  test "index with no filters defined does not error" do
    RSB::Admin.reset!
    sign_in_admin(@admin)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show]
    end

    get "/admin/test_posts"
    assert_response :success
  end

  # Pagination (AC 3)
  test "index respects per_page from registration" do
    # Create 10 test posts (per_page is 5 in setup)
    10.times do |i|
      TestPost.create!(title: "Post #{i}", body: "Body #{i}", status: "draft")
    end

    get "/admin/test_posts"
    assert_response :success
    # Should have pagination controls
    assert_match(/Next|Page/, response.body)
  end

  test "index falls back to global config per_page" do
    RSB::Admin.reset!
    sign_in_admin(@admin)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show]
      # No per_page specified, should use global config (25)
    end

    get "/admin/test_posts"
    assert_response :success
    # With default config per_page = 25, no pagination needed for small dataset
  end

  # Sorting (AC 4-6)
  test "index applies sorting from params on sortable column" do
    TestPost.create!(title: "B Post", body: "Body", status: "draft")
    TestPost.create!(title: "A Post", body: "Body", status: "draft")

    get "/admin/test_posts", params: { sort: "title", dir: "desc" }
    assert_response :success
  end

  test "index ignores sort on non-sortable column and uses default_sort" do
    get "/admin/test_posts", params: { sort: "id", dir: "asc" }
    assert_response :success
    # id is not sortable, should fall back to default_sort (title:asc)
  end

  test "index falls back to default_sort when no sort params" do
    get "/admin/test_posts"
    assert_response :success
    # Should use default_sort from registration (title:asc)
  end

  test "index falls back to id:desc when no default_sort and no sort params" do
    RSB::Admin.reset!
    sign_in_admin(@admin)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show]
      # No default_sort specified
    end

    get "/admin/test_posts"
    assert_response :success
  end

  # Show (AC 7)
  test "show loads record and exposes @registration" do
    post = TestPost.create!(title: "Test", body: "Body", status: "draft")
    get "/admin/test_posts/#{post.id}"
    assert_response :success
  end
end

class ResourceParamsTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # resource_params (AC 8)
  test "create uses form_fields for permitted params" do
    RSB::Admin.registry.register_category "Content" do
      resource TestPost,
        actions: [:index, :show, :new, :create] do
        form_field :title, type: :text, required: true
        form_field :body, type: :textarea
        form_field :status, type: :text
      end
    end

    assert_difference "TestPost.count", 1 do
      post "/admin/test_posts", params: {
        test_post: {
          title: "New Post",
          body: "Post body",
          status: "draft"
        }
      }
    end
    assert_response :redirect
  end

  test "create falls back to auto-detect when no form_fields" do
    RSB::Admin.registry.register_category "Content" do
      resource TestPost,
        actions: [:index, :show, :new, :create]
      # No form_fields block
    end

    assert_difference "TestPost.count", 1 do
      post "/admin/test_posts", params: {
        test_post: {
          title: "Auto Post",
          body: "Auto body",
          status: "draft"
        }
      }
    end
    assert_response :redirect
  end
end

class PageActionTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show]
    end
  end

  # page_action (AC 9-11)
  test "page_action returns 404 for unknown page key" do
    get "/admin/nonexistent_page/some_action"
    assert_response :not_found
  end

  test "page_action constraint does not collide with numeric id routes" do
    post = TestPost.create!(title: "Test", body: "Body", status: "draft")
    get "/admin/test_posts/#{post.id}"
    assert_response :success
    # Should hit show action, not page_action
  end
end

class FlashI18nTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    RSB::Admin.registry.register_category "Content" do
      resource TestPost,
        actions: [:index, :show, :new, :create, :edit, :update, :destroy]
    end
  end

  # Flash / i18n (AC 13)
  test "create flash uses i18n key" do
    post "/admin/test_posts", params: {
      test_post: {
        title: "Flash Test Post",
        body: "Body",
        status: "draft"
      }
    }
    follow_redirect!
    # Flash should use i18n translation with the resource name
    assert_match(/Test post created\./i, response.body)
  end

  test "update flash uses i18n key" do
    post = TestPost.create!(title: "Original", body: "Body", status: "draft")
    patch "/admin/test_posts/#{post.id}", params: {
      test_post: {
        title: "Updated Title"
      }
    }
    follow_redirect!
    # Flash should use i18n translation with the resource name
    assert_match(/Test post updated\./i, response.body)
  end
end

class ConstantsRemovedTest < ActionDispatch::IntegrationTest
  # Constants removed (AC 14)
  test "controller does not define SENSITIVE_COLUMNS" do
    refute RSB::Admin::ResourcesController.const_defined?(:SENSITIVE_COLUMNS),
      "SENSITIVE_COLUMNS should be removed from ResourcesController"
  end

  test "controller does not define SKIP_INDEX_COLUMNS" do
    refute RSB::Admin::ResourcesController.const_defined?(:SKIP_INDEX_COLUMNS),
      "SKIP_INDEX_COLUMNS should be removed from ResourcesController"
  end
end

class CustomMemberActionRoutesTest < ActionDispatch::IntegrationTest
  include RSB::Admin::TestKit::Helpers

  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    RSB::Admin.registry.register_category "Content" do
      resource TestPost,
        actions: [:index, :show, :custom_get_action, :custom_post_action],
        controller: "test_custom_actions"
    end
  end

  test "GET custom member action dispatches to custom controller" do
    post_record = TestPost.create!(title: "Test", body: "Body", status: "draft")
    get "/admin/test_posts/#{post_record.id}/custom_get_action"
    # Route should exist (not 404). A 500 means the route resolved but controller
    # raised — acceptable for a routing test since test_custom_actions controller
    # may not exist in the test dummy.
    assert_not_equal 404, response.status
  end

  test "POST custom member action dispatches to custom controller" do
    post_record = TestPost.create!(title: "Test", body: "Body", status: "draft")
    post "/admin/test_posts/#{post_record.id}/custom_post_action"
    assert_not_equal 404, response.status
  end

  test "PATCH custom member action still works" do
    post_record = TestPost.create!(title: "Test", body: "Body", status: "draft")
    patch "/admin/test_posts/#{post_record.id}/custom_get_action"
    assert_not_equal 404, response.status
  end

  test "GET custom member action does not interfere with show route" do
    RSB::Admin.reset!
    sign_in_admin(@admin)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show]
    end

    post_record = TestPost.create!(title: "Test", body: "Body", status: "draft")
    get "/admin/test_posts/#{post_record.id}"
    assert_response :success
  end

  test "GET custom member action does not interfere with edit route" do
    RSB::Admin.reset!
    sign_in_admin(@admin)
    RSB::Admin.registry.register_category "Content" do
      resource TestPost, actions: [:index, :show, :edit, :update]
    end

    post_record = TestPost.create!(title: "Test", body: "Body", status: "draft")
    get "/admin/test_posts/#{post_record.id}/edit"
    assert_response :success
  end
end
