# frozen_string_literal: true

class AccountUserExpense < ApplicationRecord

  belongs_to :account_user, required: true

  def to_log_s
    "#{account_user_id} / #{expense_amt}"
  end
end
