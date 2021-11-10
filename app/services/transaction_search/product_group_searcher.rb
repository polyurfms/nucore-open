# frozen_string_literal: true

module TransactionSearch

  class ProductGroupSearcher < BaseSearcher

    def options
      ids = Facility.find_by_sql(order_details.joins(order: :facility)
                                        .select("distinct(facilities.id), facilities.name, facilities.abbreviation")
                                        .reorder("facilities.name").to_sql)
      ProductDisplayGroup.where(facility_id: ids)
    end


    def search(params)
    end
    
    def label_name
      I18n.t("search_field.product_group")
    end

  end

end
