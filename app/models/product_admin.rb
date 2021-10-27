# frozen_string_literal: true

class ProductAdmin < ApplicationRecord

  belongs_to :user
  belongs_to :product

  delegate :facility, to: :product

  validates_numericality_of :product_id, :user_id, only_integer: true
  validates_uniqueness_of :user_id, scope: :product_id, message: "is already assigned"


  def to_log_s
    "#{user} / #{product}"
  end
end
