

class AccountTransaction < ApplicationRecord

    validates :debit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input postive value"}, allow_nil:true , label: false
    validates :credit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input postive value"}, allow_nil:true , label: false
   

    def amt
        
    end


   

end
