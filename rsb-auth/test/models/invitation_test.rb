require "test_helper"

class RSB::Auth::InvitationTest < ActiveSupport::TestCase
  test "validates email presence" do
    invitation = RSB::Auth::Invitation.new(email: "")
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "can't be blank"
  end

  test "validates email format" do
    invitation = RSB::Auth::Invitation.new(email: "not-an-email")
    assert_not invitation.valid?
  end

  test "normalizes email to lowercase stripped" do
    invitation = RSB::Auth::Invitation.create!(email: "  Test@EXAMPLE.COM  ")
    assert_equal "test@example.com", invitation.email
  end

  test "generates token on creation" do
    invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
    assert invitation.token.present?
    assert invitation.token.length >= 32
  end

  test "sets expiry on creation (7 days)" do
    freeze_time do
      invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
      assert_equal 7.days.from_now, invitation.expires_at
    end
  end

  test "pending? returns true for fresh invitation" do
    invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
    assert invitation.pending?
  end

  test "accept! marks invitation as accepted" do
    freeze_time do
      invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
      invitation.accept!
      assert invitation.accepted?
      assert_equal Time.current, invitation.accepted_at
    end
  end

  test "revoke! marks invitation as revoked" do
    freeze_time do
      invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
      invitation.revoke!
      assert invitation.revoked?
      assert_equal Time.current, invitation.revoked_at
    end
  end

  test "expired? returns true when past expiry" do
    invitation = RSB::Auth::Invitation.create!(email: "invite@example.com")
    invitation.update_columns(expires_at: 1.hour.ago)
    assert invitation.expired?
  end

  test "pending scope returns only pending invitations" do
    pending = RSB::Auth::Invitation.create!(email: "pending@example.com")

    accepted = RSB::Auth::Invitation.create!(email: "accepted@example.com")
    accepted.accept!

    expired = RSB::Auth::Invitation.create!(email: "expired@example.com")
    expired.update_columns(expires_at: 1.hour.ago)

    result = RSB::Auth::Invitation.pending
    assert_includes result, pending
    assert_not_includes result, accepted
    assert_not_includes result, expired
  end

  test "invited_by is polymorphic and optional" do
    reflection = RSB::Auth::Invitation.reflect_on_association(:invited_by)
    assert_equal :belongs_to, reflection.macro
    assert reflection.options[:polymorphic]
    assert reflection.options[:optional]
  end

  test "creates invitation without invited_by" do
    invitation = RSB::Auth::Invitation.create!(email: "test@example.com")
    assert_nil invitation.invited_by
  end
end
