class Supervisor < ApplicationRecord

  belongs_to :user, inverse_of: :supervisor

end
