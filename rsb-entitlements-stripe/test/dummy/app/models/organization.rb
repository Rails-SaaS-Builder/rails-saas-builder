# frozen_string_literal: true

class Organization < ApplicationRecord
  include RSB::Entitlements::Entitleable
end
