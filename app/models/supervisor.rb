class Supervisor < ApplicationRecord

  belongs_to :user, inverse_of: :supervisor

  def to_log_s
    "#{last_name} / #{first_name} / #{email}"
  end

end
