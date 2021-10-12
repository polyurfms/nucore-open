# frozen_string_literal: true

class AdditionalPriceGroup < ApplicationRecord

#  has_many :order_details

  belongs_to :order_detail, inverse_of: :order_detail
  has_many :additional_price_policies

  #validates :name, uniqueness: true

  def to_log_s
  end

  def self.select_additional_price_groups(product_id)
    @price_policies = PricePolicy.where("start_date > :now or (start_date <= :now AND expire_date > :now)", now: Time.zone.now).pluck :id
    # where("product_id = :product_id AND deleted_at IS NULL", product_id: product_id)
    joins("INNER JOIN additional_price_policies ON additional_price_groups.id = additional_price_policies.additional_price_group_id INNER JOIN price_policies ON price_policies.id = additional_price_policies.price_policy_id ")
    .where("price_policies.product_id = :product_id AND price_policies.id IN (:price_policy_id)", product_id: product_id, price_policy_id: @price_policies).uniq
  end

  def self.delete_price_groups(id)
      where(id = :id, id: id).destory_all
  end

end
