class CreatePaymentSourceRequestSearches < ActiveRecord::Migration[5.2]
  def change
    create_view :payment_source_request_searches
  end
end
