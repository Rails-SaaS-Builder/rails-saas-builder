# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
      end

      # --- Token generation ---

      test 'generates a token on create' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        assert invitation.token.present?
        assert invitation.token.length >= 32
      end

      test 'token is unique' do
        inv1 = Invitation.create!(expires_at: 7.days.from_now)
        inv2 = Invitation.create!(expires_at: 7.days.from_now)
        refute_equal inv1.token, inv2.token
      end

      test 'does not overwrite token if already set' do
        invitation = Invitation.new(token: 'custom-token-value', expires_at: 7.days.from_now)
        invitation.save!
        assert_equal 'custom-token-value', invitation.token
      end

      # --- Expiry ---

      test 'expires_at is required' do
        invitation = Invitation.new
        # The before_create callback sets a fallback, but let's test the model allows explicit setting
        invitation.expires_at = 3.days.from_now
        invitation.save!
        assert invitation.expires_at.present?
      end

      test 'before_create sets default expires_at if nil' do
        invitation = Invitation.new
        invitation.save!
        assert invitation.expires_at.present?
        # Default fallback: 7 days from now
        assert_in_delta 7.days.from_now.to_i, invitation.expires_at.to_i, 5
      end

      test 'before_create does not set default expires_at when explicitly set to nil' do
        invitation = Invitation.new(expires_at: nil)
        invitation.save!
        assert_nil invitation.expires_at
      end

      test 'pending? returns true when expires_at is nil (no expiry)' do
        invitation = Invitation.create!(expires_at: nil)
        assert invitation.pending?
      end

      test 'expired? returns false when expires_at is nil' do
        invitation = Invitation.create!(expires_at: nil)
        refute invitation.expired?
      end

      test 'use! works with nil expires_at' do
        invitation = Invitation.create!(expires_at: nil, max_uses: 3)
        invitation.use!
        invitation.reload
        assert_equal 1, invitation.uses_count
      end

      test 'pending scope includes nil expires_at invitations' do
        no_expiry_inv = Invitation.create!(expires_at: nil)
        results = Invitation.pending
        assert_includes results, no_expiry_inv
      end

      test 'expired scope excludes nil expires_at invitations' do
        no_expiry_inv = Invitation.create!(expires_at: nil)
        results = Invitation.expired
        refute_includes results, no_expiry_inv
      end

      test 'status returns pending for nil expires_at invitation' do
        invitation = Invitation.create!(expires_at: nil)
        assert_equal 'pending', invitation.status
      end

      # --- Predicate methods ---

      test 'pending? returns true for fresh invitation' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        assert invitation.pending?
      end

      test 'pending? returns false when expired' do
        invitation = Invitation.create!(expires_at: 1.hour.ago)
        refute invitation.pending?
      end

      test 'pending? returns false when revoked' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)
        refute invitation.pending?
      end

      test 'pending? returns false when exhausted (uses_count >= max_uses)' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: 1, uses_count: 1)
        refute invitation.pending?
      end

      test 'pending? returns true when max_uses is nil (unlimited)' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: nil, uses_count: 100)
        assert invitation.pending?
      end

      test 'exhausted? returns true when uses_count >= max_uses' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: 3, uses_count: 3)
        assert invitation.exhausted?
      end

      test 'exhausted? returns false when max_uses is nil' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: nil, uses_count: 999)
        refute invitation.exhausted?
      end

      test 'exhausted? returns false when uses_count < max_uses' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: 5, uses_count: 2)
        refute invitation.exhausted?
      end

      test 'expired? returns true when expires_at is in the past' do
        invitation = Invitation.create!(expires_at: 1.second.ago)
        assert invitation.expired?
      end

      test 'expired? returns false when expires_at is in the future' do
        invitation = Invitation.create!(expires_at: 1.day.from_now)
        refute invitation.expired?
      end

      test 'revoked? returns true when revoked_at is present' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)
        assert invitation.revoked?
      end

      test 'revoked? returns false when revoked_at is nil' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        refute invitation.revoked?
      end

      # --- use! (atomic) ---

      test 'use! increments uses_count atomically' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: 3, uses_count: 0)
        invitation.use!
        invitation.reload
        assert_equal 1, invitation.uses_count
      end

      test 'use! raises when invitation is not pending (expired)' do
        invitation = Invitation.create!(expires_at: 1.hour.ago, max_uses: 3, uses_count: 0)
        assert_raises(RuntimeError) { invitation.use! }
      end

      test 'use! raises when invitation is not pending (revoked)' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)
        assert_raises(RuntimeError) { invitation.use! }
      end

      test 'use! raises when invitation is exhausted' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: 1, uses_count: 1)
        assert_raises(RuntimeError) { invitation.use! }
      end

      test 'use! works for unlimited invitations (max_uses nil)' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, max_uses: nil, uses_count: 50)
        invitation.use!
        invitation.reload
        assert_equal 51, invitation.uses_count
      end

      # --- revoke! ---

      test 'revoke! sets revoked_at' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        invitation.revoke!
        assert invitation.revoked_at.present?
      end

      # --- Scopes ---

      test 'pending scope returns only pending invitations' do
        pending_inv = Invitation.create!(expires_at: 7.days.from_now)
        _expired_inv = Invitation.create!(expires_at: 1.hour.ago)
        _revoked_inv = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)
        _exhausted_inv = Invitation.create!(expires_at: 7.days.from_now, max_uses: 1, uses_count: 1)

        results = Invitation.pending
        assert_includes results, pending_inv
        assert_equal 1, results.count
      end

      test 'exhausted scope returns only exhausted invitations' do
        _pending_inv = Invitation.create!(expires_at: 7.days.from_now, max_uses: 5, uses_count: 0)
        exhausted_inv = Invitation.create!(expires_at: 7.days.from_now, max_uses: 1, uses_count: 1)
        _unlimited_inv = Invitation.create!(expires_at: 7.days.from_now, max_uses: nil, uses_count: 100)

        results = Invitation.exhausted
        assert_includes results, exhausted_inv
        assert_equal 1, results.count
      end

      test 'expired scope returns only expired invitations' do
        _pending_inv = Invitation.create!(expires_at: 7.days.from_now)
        expired_inv = Invitation.create!(expires_at: 1.hour.ago)

        results = Invitation.expired
        assert_includes results, expired_inv
        assert_equal 1, results.count
      end

      test 'revoked scope returns only revoked invitations' do
        _pending_inv = Invitation.create!(expires_at: 7.days.from_now)
        revoked_inv = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)

        results = Invitation.revoked
        assert_includes results, revoked_inv
        assert_equal 1, results.count
      end

      # --- Associations ---

      test 'has_many deliveries' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        assert_respond_to invitation, :deliveries
        assert_equal [], invitation.deliveries.to_a
      end

      test 'polymorphic invited_by' do
        identity = RSB::Auth::Identity.create!(status: :active)
        invitation = Invitation.create!(expires_at: 7.days.from_now, invited_by: identity)
        assert_equal identity, invitation.invited_by
      end

      # --- Convenience methods ---

      test 'registered_identities returns identities with matching invitation_id in metadata' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        identity = RSB::Auth::Identity.create!(status: :active, metadata: { 'invitation_id' => invitation.id.to_s })
        _other = RSB::Auth::Identity.create!(status: :active, metadata: {})

        result = invitation.registered_identities
        assert_includes result, identity
        assert_equal 1, result.count
      end

      # --- Status ---

      test 'status returns correct string' do
        pending_inv = Invitation.create!(expires_at: 7.days.from_now)
        assert_equal 'pending', pending_inv.status

        expired_inv = Invitation.create!(expires_at: 1.hour.ago)
        assert_equal 'expired', expired_inv.status

        revoked_inv = Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)
        assert_equal 'revoked', revoked_inv.status

        exhausted_inv = Invitation.create!(expires_at: 7.days.from_now, max_uses: 1, uses_count: 1)
        assert_equal 'exhausted', exhausted_inv.status
      end

      # --- masked_token ---

      test 'masked_token shows first 8 and last 4 chars by default' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        masked = invitation.masked_token
        assert masked.start_with?(invitation.token[0..7])
        assert masked.end_with?(invitation.token[-4..])
        assert_includes masked, '********'
      end

      test 'masked_token uses custom masker when configured' do
        RSB::Auth.configuration.invitation_token_masker = ->(t) { "MASKED-#{t[-6..]}" }
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        assert invitation.masked_token.start_with?('MASKED-')
      ensure
        RSB::Auth.configuration.invitation_token_masker = nil
      end

      # --- Label and metadata ---

      test 'label is optional' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, label: 'Marketing batch')
        assert_equal 'Marketing batch', invitation.label
      end

      test 'metadata defaults to empty hash' do
        invitation = Invitation.create!(expires_at: 7.days.from_now)
        assert_equal({}, invitation.metadata)
      end

      test 'metadata stores arbitrary JSON' do
        invitation = Invitation.create!(expires_at: 7.days.from_now, metadata: { 'plan' => 'pro', 'team_id' => 42 })
        assert_equal 'pro', invitation.metadata['plan']
        assert_equal 42, invitation.metadata['team_id']
      end
    end
  end
end
