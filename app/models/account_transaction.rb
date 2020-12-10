

class AccountTransaction < ApplicationRecord

    OPERATION_TYPES = {
      LOCK_FUND_REQUEST: ["LOCK_FUND_REQUEST"],
      UNLOCK_FUND_REQUEST: ["UNLOCK_FUND_REQUEST"],
    }.with_indifferent_access

    validates :debit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input postive value"}, allow_nil:true , label: false
    validates :credit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input postive value"}, allow_nil:true , label: false

    attr_accessor :operation_amount

    def self.operation_types
      OPERATION_TYPES.values.flatten.uniq
    end

    def operation_amount
        if (operation_type == "LOCK_FUND_REQUEST")
          self.debit_amt
        else
          self.credit_amt
        end
    end

    def operation_amount=(value)
      if (operation_type == "LOCK_FUND_REQUEST")
        self.debit_amt = value
      else
        self.credit_amt = value
      end
    end


end
