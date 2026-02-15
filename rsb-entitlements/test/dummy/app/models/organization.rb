# frozen_string_literal: true

class Organization < ActiveRecord::Base
  include RSB::Entitlements::Entitleable
end
