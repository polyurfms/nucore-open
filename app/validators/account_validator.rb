# frozen_string_literal: true

class AccountValidator < ActiveModel::Validator
  def validate(record)

    total_allocation_amt = record.account_users.sum {|h| h[:allocation_amt].to_f}

    if record.committed_amt < total_allocation_amt
      record.errors.add(:base, "Allocation amount cannot be larger than committed amount.")
    end
  end
end
