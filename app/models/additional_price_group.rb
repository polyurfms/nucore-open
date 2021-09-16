# frozen_string_literal: true

class AdditionalPriceGroup < ApplicationRecord

#  has_many :order_details

  belongs_to :order_detail, inverse_of: :order_detail
  has_many :additional_price_policies

  #validates :name, uniqueness: true

  def to_log_s
  end

  def self.select_additional_price_groups(product_id)
    where("product_id = :product_id AND deleted_at IS NULL", product_id: product_id)
  end

  def self.delete_price_groups(id)
      where(id = :id, id: id).destory_all
  end

end
