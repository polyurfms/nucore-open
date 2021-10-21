# frozen_string_literal: true

class AdditionalPricePolicy < ApplicationRecord

  has_many :log_events, as: :loggable
  belongs_to :price_policy
  belongs_to :additional_price_group

  def to_log_s
  end

  def name
    additional_price_group.name
  end

  def self.get_additional_price_policy_list(id)
    where("price_policy_id = :id AND deleted_at IS NULL", id: id)
  end

  def self.get_duplcation_additional_price_policy_list(search_price_polic_id, addition_price_name, search_additional_price_policies_id)
    where("price_policy_id IN (?) AND name = ? AND deleted_at IS NULL AND id NOT IN (?) ", search_price_polic_id, addition_price_name, search_additional_price_policies_id).order(name: :asc, price_policy_id: :asc).count
  end
  
  def self.get_additional_price_policy_list_for_show(id)
    joins("INNER JOIN price_policies on price_policies.id = additional_price_policies.price_policy_id").where("price_policy_id IN (?)", get_search_id(id)).where("deleted_at IS NULL").order(start_date: :desc, expire_date: :desc, additional_price_group_id: :asc, price_policy_id: :asc)
  end

  private
  def self.get_search_id(price_policies)
    search_id = Array.new
    price_policies.each do |p| 
      search_id << p.id if p.can_purchase
    end
    return search_id
  end
end
