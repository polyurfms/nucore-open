class UserDelegation < ApplicationRecord
  belongs_to :user
  has_many :log_events, as: :loggable
  validates :delegatee, :delegator, presence: true

  def to_log_s
    "Delegatee - #{delegatee}"
  end
end
