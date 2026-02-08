module RSB
  module Auth
    class Credential::EmailPassword < Credential
      validates :identifier, format: { with: URI::MailTo::EMAIL_REGEXP }
    end
  end
end
