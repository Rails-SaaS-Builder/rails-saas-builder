require "test_helper"

class AdminUserEmailVerificationTest < ActiveSupport::TestCase
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
  end

  # ── generate_email_verification! ───────────────────

  test "generate_email_verification! sets pending fields" do
    @admin.generate_email_verification!("new@example.com")
    @admin.reload

    assert_equal "new@example.com", @admin.pending_email
    assert_not_nil @admin.email_verification_token
    assert_not_nil @admin.email_verification_sent_at
  end

  test "generate_email_verification! normalizes email" do
    @admin.generate_email_verification!("  NEW@Example.COM  ")
    @admin.reload
    assert_equal "new@example.com", @admin.pending_email
  end

  test "generate_email_verification! fails if pending email is taken" do
    RSB::Admin::AdminUser.create!(
      email: "taken@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      @admin.generate_email_verification!("taken@example.com")
    end
  end

  # ── verify_email! ──────────────────────────────────

  test "verify_email! moves pending to email" do
    @admin.generate_email_verification!("new@example.com")
    @admin.verify_email!
    @admin.reload

    assert_equal "new@example.com", @admin.email
    assert_nil @admin.pending_email
    assert_nil @admin.email_verification_token
    assert_nil @admin.email_verification_sent_at
  end

  # ── email_verification_pending? ────────────────────

  test "email_verification_pending? returns true when pending" do
    @admin.generate_email_verification!("new@example.com")
    assert @admin.email_verification_pending?
  end

  test "email_verification_pending? returns false when not pending" do
    refute @admin.email_verification_pending?
  end

  # ── email_verification_expired? ────────────────────

  test "email_verification_expired? returns false within expiry window" do
    @admin.generate_email_verification!("new@example.com")
    refute @admin.email_verification_expired?
  end

  test "email_verification_expired? returns true after expiry" do
    @admin.generate_email_verification!("new@example.com")
    travel RSB::Admin.configuration.email_verification_expiry + 1.minute do
      assert @admin.email_verification_expired?
    end
  end

  test "email_verification_expired? returns true when no sent_at" do
    assert @admin.email_verification_expired?
  end
end
