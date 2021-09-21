class RequestEndorsement < ApplicationRecord
  belongs_to :user
  has_many :log_events, as: :loggable
  validates :user_id, :supervisor, presence: true

end
