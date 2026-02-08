module RSB
  module Auth
    class ApplicationMailer < ActionMailer::Base
      default from: "noreply@example.com"
      layout "mailer"
    end
  end
end
