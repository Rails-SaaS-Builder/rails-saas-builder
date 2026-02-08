# Wire Identity to Entitlements (cross-gem integration)
# This is how host apps would integrate the two gems that have no dependency on each other.
Rails.application.config.to_prepare do
  RSB::Auth::Identity.include(RSB::Entitlements::Entitleable)
end

# # Configure RSB::Admin theme
# RSB::Admin.configure do |config|
#   config.theme = :modern
# end
