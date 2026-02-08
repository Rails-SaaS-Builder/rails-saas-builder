# A simple test model used to exercise the generic ResourcesController
# in integration tests. Not part of the production admin engine.
class TestPost < ApplicationRecord
  validates :title, presence: true
end
