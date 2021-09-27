

class FundingRequest < ApplicationRecord

    REQUEST_TYPES = {
      LOCK_FUND_REQUEST: ["LOCK_FUND_REQUEST"],
      UNLOCK_FUND_REQUEST: ["UNLOCK_FUND_REQUEST"],
    }.with_indifferent_access

    validates_presence_of :request_type, allow_nil:false
#    validates :debit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input non zero positive value"}, allow_nil:true , label: false
#    validates :credit_amt, numericality: {greater_than_or_equal_to: 1, message: "Please input non zero positive value"}, allow_nil:true , label: false
    validates :request_amount, numericality: {greater_than_or_equal_to: 1, message: "Please input non zero positive value"}, allow_nil:false , label: false

    attr_accessor :request_amount

    def self.request_types
      REQUEST_TYPES.values.flatten.uniq
    end

    def request_amount
      if (request_type == "LOCK_FUND_REQUEST")
        self.debit_amt
      else
        self.credit_amt
      end
    end

    def request_amount=(value)
      if (request_type == "LOCK_FUND_REQUEST" )
        self.debit_amt = value
      else
        self.credit_amt = value
      end
    end

    def to_s
      "Ref. No. #{id}, #{request_type}"
    end


end
