# frozen_string_literal: true

require 'test_helper'

class AdminPlansTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Index ---

  test 'index lists plans' do
    RSB::Entitlements::Plan.create!(key: 'pro', name: 'Pro')
    get '/admin/plans'
    assert_response :success
    assert_match 'Pro', response.body
  end

  # --- Show ---

  test 'show displays plan details' do
    plan = RSB::Entitlements::Plan.create!(key: 'enterprise', name: 'Enterprise')
    get "/admin/plans/#{plan.id}"
    assert_response :success
    assert_match 'Enterprise', response.body
    assert_match 'enterprise', response.body
  end

  # --- New / Create ---

  test 'new renders the plan form' do
    get '/admin/plans/new'
    assert_response :success
    assert_match 'Name', response.body
  end

  test 'create with valid params' do
    assert_difference 'RSB::Entitlements::Plan.count', 1 do
      post '/admin/plans', params: {
        plan: {
          key: 'business',
          name: 'Business',
          display_order: 10
        }
      }
    end

    plan = RSB::Entitlements::Plan.last
    assert_redirected_to "/admin/plans/#{plan.id}"
    assert_equal 'Business', plan.name
    assert_equal 'business', plan.key
  end

  test 'create with missing key re-renders form' do
    post '/admin/plans', params: { plan: { name: '' } }
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test 'edit renders form with existing values' do
    plan = RSB::Entitlements::Plan.create!(key: 'pro', name: 'Pro')
    get "/admin/plans/#{plan.id}/edit"
    assert_response :success
    assert_match 'Pro', response.body
  end

  test 'update changes plan name' do
    plan = RSB::Entitlements::Plan.create!(key: 'pro', name: 'Pro')
    patch "/admin/plans/#{plan.id}", params: { plan: { name: 'Pro Plus' } }
    assert_redirected_to "/admin/plans/#{plan.id}"
    assert_equal 'Pro Plus', plan.reload.name
  end

  # --- RBAC ---

  test 'restricted admin cannot access plans' do
    restricted = create_test_admin!(permissions: { 'other' => ['index'] })
    sign_in_admin(restricted)
    get '/admin/plans'
    assert_includes [302, 403], response.status
  end
end
