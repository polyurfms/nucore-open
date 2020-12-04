class UserDelegation < ApplicationRecord
  belongs_to :user
  validates :delegatee, :delegator, presence: true
end
