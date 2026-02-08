class Organization < ActiveRecord::Base
  include RSB::Entitlements::Entitleable
end
