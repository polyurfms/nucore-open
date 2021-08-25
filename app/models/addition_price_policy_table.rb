# frozen_string_literal: true

class AdditionPricePolicyTable

  include ActiveModel::Model
  include TextHelpers::Translation
  include DateHelper

  attr_accessor :current_price_policies, :addition_price_policies

  def initialize(price_policy)
    
  end

end
