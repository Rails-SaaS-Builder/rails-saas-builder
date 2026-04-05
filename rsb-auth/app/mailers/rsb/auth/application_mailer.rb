# frozen_string_literal: true

module RSB
  module Auth
    class ApplicationMailer < ActionMailer::Base
      default from: -> { RSB::Settings.get('auth.mailer_from') }
      layout 'mailer'
    end
  end
end
