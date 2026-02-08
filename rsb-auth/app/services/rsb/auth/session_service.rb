module RSB
  module Auth
    class SessionService
      def create(identity:, ip_address:, user_agent:)
        enforce_session_limit(identity)
        session = identity.sessions.create!(
          ip_address: ip_address,
          user_agent: user_agent,
          last_active_at: Time.current
        )
        session
      end

      def find_by_token(token)
        return nil if token.blank?
        session = RSB::Auth::Session.active.find_by(token: token)
        return nil unless session
        session.touch_activity!
        session
      end

      def revoke(session)
        session.revoke!
      end

      def revoke_all(identity, except: nil)
        scope = identity.sessions.active
        scope = scope.where.not(id: except.id) if except
        scope.update_all(expires_at: Time.current)
      end

      private

      def enforce_session_limit(identity)
        max = RSB::Settings.get("auth.max_sessions")
        active_count = identity.sessions.active.count
        if active_count >= max
          oldest = identity.sessions.active.order(:created_at).first
          oldest&.revoke!
        end
      end
    end
  end
end
