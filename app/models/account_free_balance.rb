# frozen_string_literal: true

class AccountFreeBalance < ApplicationRecord

  belongs_to :account, required: true

  def to_log_s
    "#{account_id} / #{total_expense}"
  end
end
