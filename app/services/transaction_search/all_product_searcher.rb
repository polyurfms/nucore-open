# frozen_string_literal: true

module TransactionSearch

  class AllProductSearcher < BaseSearcher

    def options
      Product.new.get_all_product?(order_details)
    end

    def search(params)
    end

    def data_attrs(product)
      {
        facility: product.facility_id,
        product_group: product.product_display_group_product.nil? ? 0 : product.product_display_group_product.product_display_group_id,
        restricted: product.requires_approval?,
        product_type: product.type.downcase,
      }
    end
    
    def label_name
      I18n.t("search_field.product")
    end

  end

end
