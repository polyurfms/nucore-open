# frozen_string_literal: true

class ProductAdminsController < ApplicationController

  include SearchHelper
  include BelongsToProductController

  admin_tab :index, :new
  before_action :init_current_facility
#  before_action :init_facility_staff


  load_and_authorize_resource

  layout "two_column"

  def initialize
    @active_tab = "admin_products"
    super
  end

  # GET /facilities/:facility_id/bundles/bundle_id/admins
  # GET /facilities/:facility_id/instruments/instrument_id/admins
  # GET /facilities/:facility_id/items/item_id/admins
  # GET /facilities/:facility_id/services/service_id/admins
  def index
    @facility_staffs = User.find_users_by_facility(current_facility)
    @product_admin_by_user = @product.product_admins.pluck(:user_id, :product_id).to_h
    puts "<<< #{@product_admin_by_user}"
  end

  # POST /facilities/:facility_id/instruments/:instrument_id/update_restrictions
  def create

    @facility_staffs = User.find_users_by_facility(current_facility)

    if update_admin_assignemnts.grants_changed?
      flash[:notice] = I18n.t "controllers.users.product_admin_list.assingment_update.notice",
                              granted: update_admin_assignemnts.granted, revoked: update_admin_assignemnts.revoked
      update_admin_assignemnts.granted_product_admins.each do |product_admin|
        LogEvent.log(product_admin, :create, current_user)
      end
      update_admin_assignemnts.revoked_product_admins.each do |product_admin|
        LogEvent.log(product_admin, :delete, current_user)
      end
    end

    redirect_to action: :index
  end

  private

  def approved_admin_from_params
    if params[:approved_admins].present?
      User.find(params[:approved_admins])
    else
      []
    end
  end

  def update_admin_assignemnts
    puts "xxxxxxxxxx #{@product.inspect}"
    puts "xxxxxxxxxx #{@facility_staffs.inspect}"

    @update_product_assignment ||= ProductAdminAssigner.new().update_product_administrator(@product, @facility_staffs, approved_admin_from_params)
  end

  def downcase_product_type
    @product.class.model_name.human.downcase
  end

  def init_facility_staff
    puts "init facility staff"
    #@facility_staffs = User.find_users_by_facility(current_facility).build # for CanCan auth
  end

end
