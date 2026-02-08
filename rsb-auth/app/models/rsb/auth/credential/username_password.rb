module RSB
  module Auth
    class Credential::UsernamePassword < Credential
      validates :identifier, format: { with: /\A[\w.]+\z/ }, length: { in: 3..30 }
    end
  end
end
