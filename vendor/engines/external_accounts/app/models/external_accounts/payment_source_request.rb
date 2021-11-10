module ExternalAccounts

  class PaymentSourceRequest < ApplicationRecord

    # validates :is_overtime, :presence => true

    def to_s
      name
    end

  end

end
