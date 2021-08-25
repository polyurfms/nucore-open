# frozen_string_literal: true

class AdditionPricePolicy < ApplicationRecord
  
  has_many :log_events, as: :loggable
  belongs_to :price_policy

    
  def to_log_s
  end

  
  def self.get_addition_price_policy_list(id)
    where("price_policy_id = :id AND deleted_at IS NULL", id: id)
  end

  def self.get_duplcation_addition_price_policy_list(search_price_polic_id, addition_price_name, search_addition_price_policies_id)
    where("price_policy_id IN (?) AND name = ? AND deleted_at IS NULL AND id NOT IN (?) ", search_price_polic_id, addition_price_name, search_addition_price_policies_id).order(name: :asc, price_policy_id: :asc).count
  end
end
