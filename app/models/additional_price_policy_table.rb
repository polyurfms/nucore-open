# frozen_string_literal: true

class AdditionalPricePolicyTable

  include ActiveModel::Model
  include TextHelpers::Translation
  include DateHelper

  attr_accessor :current_price_policies, :additional_price_policies

  def initialize(price_policy)

  end

end
