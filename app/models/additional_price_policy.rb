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
end
