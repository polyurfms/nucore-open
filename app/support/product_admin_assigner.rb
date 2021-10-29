# frozen_string_literal: true

class ProductAdminAssigner

  class Stats

    attr_reader :granted_product_admins, :revoked_product_admins

    def initialize
      @access_groups_changed = 0
      @granted_product_admins = []
      @revoked_product_admins = []
    end

    def grant(product_admin)
      @granted_product_admins << product_admin
    end

    def granted
      @granted_product_admins.count
    end

    def revoke(product_admin)
      @revoked_product_admins << product_admin
    end

    def revoked
      @revoked_product_admins.count
    end

    def grants_changed?
      granted + revoked > 0
    end

  end

  def update_assignments(user, all_products, products_to_assign)

    @all_products = all_products
    @user = user

    @all_products.each_with_object(Stats.new) do |product, stats|
      if products_to_assign.include?(product)
        product_user = approve_access(product)
        stats.grant(product_user) if product_user
      else
        product_user = revoke_access(product)
        stats.revoke(product_user) if product_user
      end
    end
  end

  def update_product_administrator(product, facility_staffs, staff_to_assign)
#    @all_facility_staffs = all_facility_staff

    facility_staffs.each_with_object(Stats.new) do |user, stats|
      @user = user
      
      if staff_to_assign.include?(user)
        product_user = approve_access(product)
        stats.grant(product_user) if product_user
      else
        product_user = revoke_access(product)
        stats.revoke(product_user) if product_user
      end
    end

  end

  def approve_access(product)
    create_product_admin(product)
  end

  def revoke_access(product)
    destroy_product_admin(product)
  end

  private

  def create_product_admin(product)
    ProductAdminCreator.create(product: product, user: @user)
  end

  def destroy_product_admin(product)
    product_admin = get_product_admin(product)
    product_admin.try(:destroy)
  end

  def get_product_admin(product)
    product.product_admins.find_by(user_id: @user.id)
  end

end
