class Organization < ApplicationRecord
  include RSB::Entitlements::Entitleable
end
