# frozen_string_literal: true

class ProductAdminCreator

  def self.create(user:, product:)
    product_admin = ProductAdmin.new(
      product: product,
      user: user
    )

    product_admin.transaction do
      product_admin.save
    end
    product_admin
  end

end
