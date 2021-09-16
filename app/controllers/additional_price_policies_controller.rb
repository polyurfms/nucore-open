# frozen_string_literal: true

class AdditionalPricePoliciesController < ApplicationController

  include DateHelper

  admin_tab     :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_current_facility
  before_action :init_product

  layout "two_column"

  def initialize
    @active_tab = "admin_products"

    super
  end

  def index
    @date_range_start = format_usa_date(Time.zone.now)
    @search_form = TransactionSearch::SearchForm.new(
      params[:search],
      defaults: {
        date_range_start: @date_range_start
      },
    )

    unless params[:search].nil?
      unless params[:search][:date_range_start].nil?
        @date_range_start = params[:search][:date_range_start]
        @search_form.date_range_start = @date_range_start
      end
    end

    # @current_price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: parse_usa_date(@date_range_start)).joins(:additional_price_policy).order(name: :asc)

    @current_price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: parse_usa_date(@date_range_start)).order(id: :asc)

    @current_start_date = @current_price_policies.first.try(:start_date) unless @current_price_policies.nil?
    @current_expires_date = @current_price_policies.first.try(:expire_date) unless @current_price_policies.nil?

    @search_id = @current_price_policies.select(&:can_purchase?).map do |price_policy|
      price_policy.id
    end

    @current_additional_price_policies = AdditionalPricePolicy.where("price_policy_id IN (?)", @search_id).where("deleted_at IS NULL").order(additional_price_group_id: :asc, price_policy_id: :asc)
    render "additional_price_policies/index"
  end


  def add
    @params = params.permit(:facility_id, :instrument_id, :additional_price_policy_id)

    return redirect_to facility_instrument_additional_price_policies_path if @params[:additional_price_policy_id].blank?

    @price_policy_date = @params[:additional_price_policy_id]
    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?

    raise ActiveRecord::RecordNotFound if @price_policies.blank?
    @additional_price_policies = get_new_additional_price_policies(@price_policies)
    raise ActiveRecord::RecordNotFound if @additional_price_policies.blank?
  end

  def create
    @params = params.permit(:addition_price_name, :startdate, :facility_id, :instrument_id)
    return redirect_to facility_instrument_additional_price_policies_path if @params[:startdate].blank?

    @addition_price_name = @params[:addition_price_name] || ""
    @price_policy_date = @params[:startdate]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    @additional_price_policies = get_new_additional_price_policies(@price_policies)

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?

    @additional_price_group = AdditionalPriceGroup.new
    @additional_price_group.name = @addition_price_name
    @additional_price_group.product_id = @product.id

    @date = Time.zone.now
    @additional_price_policies.each do |additional_price_policy|
      #additional_price_policy.name = @addition_price_name
      additional_price_policy.cost = params["price_policy_#{additional_price_policy.price_policy.id}"][:cost]
      additional_price_policy.created_at = @date
      additional_price_policy.updated_at = @date
      additional_price_policy.created_by = current_user.id
    end

#    @additional_price_group.additional_price_policies = @additional_price_policies

    @search_price_polic_id = @price_policies.map do |price_policy|
      price_policy.id
    end

#    @duplcation = AdditionalPricePolicy.where("price_policy_id IN (?) AND name = ? AND deleted_at IS NULL", @search_price_polic_id, @addition_price_name).order(name: :asc, price_policy_id: :asc).count

    if @addition_price_name.eql?("") # || @duplcation > 0
      flash.now[:error] = text("errors.null_name") if @addition_price_name.eql?("")
      flash.now[:error] = text("errors.duplcation_name") if @duplcation > 0
      return render :add
    else
      ActiveRecord::Base.transaction do
        begin
          if @additional_price_group.save!
            @additional_price_policies.each do |app|
              app.additional_price_group_id = @additional_price_group.id
            end
            @additional_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
          else
            raise(ActiveRecord::Rollback)
          end

        end
      rescue => e
        flash.now[:error] = text("errors.save")
        return render :add
      end
    end
    redirect_to facility_instrument_additional_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})
    # redirect_to facility_instrument_additional_price_policies_path(@params[:facility_id] , @params[:instrument_id])
  end

  def update
    # @params_info = params.permit(:facility_id, :instrument_id)
    @params = params[:additional_price_policy]

#    return redirect_to facility_instrument_additional_price_policies_path if @params[:startdate].blank?

    @additonal_price_group_id = params[:additional_price_group][:additional_price_group_id]

    @additional_price_group = AdditionalPriceGroup.find_by(id: @additonal_price_group_id)
    @additional_price_group.name = params[:additional_price_group][:name]

    #@addition_price_name = params[:addition_price_name] || ""
    #@price_policy_date = @params[:startdate]

    @price_policy_date = params[:additional_price_policy_id]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    @additional_price_policies = get_new_additional_price_policies(@price_policies)

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?

    @additional_price_policies.each do |additional_price_policy|
      additional_price_policy.id = params["price_policy_#{additional_price_policy.price_policy.id}"][:id]
      #additional_price_policy.name = @addition_price_name
      additional_price_policy.cost = params["price_policy_#{additional_price_policy.price_policy.id}"][:cost]
      #additional_price_policy.product_price_group.name = @addition_price_name
    end

    @search_price_policy_id = @price_policies.map do |price_policy|
      price_policy.id
    end

    @search_additional_price_policies_id = @additional_price_policies.map do |additional_price_policies|
      params["price_policy_#{additional_price_policies.price_policy.id}"][:id]
    end

#    @duplcation = AdditionalPricePolicy.where("price_policy_id IN (?) AND product_price_group_id = ? AND deleted_at IS NULL AND id NOT IN (?) ", @search_price_policy_id, @product_price_group_id, @search_additional_price_policies_id).order(name: :asc, price_policy_id: :asc).count

#    if @addition_price_name.eql?("") || @duplcation > 0
#      flash.now[:error] = text("errors.null_name") if @addition_price_name.eql?("")
#      flash.now[:error] = text("errors.duplcation_name") if @duplcation > 0
#      return render :edit
#    else
      ActiveRecord::Base.transaction do
        begin
          @date = Time.zone.now

          @additional_price_policies.each do |additional_price_policy|
            id = params["price_policy_#{additional_price_policy.price_policy.id}"][:id]
            name = @additional_price_group.name
            cost = params["price_policy_#{additional_price_policy.price_policy.id}"][:cost]

            @a = AdditionalPricePolicy.find(id.to_i)
            unless @a.update(:cost => cost, :updated_at => @date)
              flash.now[:error] = text("errors")
              raise(ActiveRecord::Rollback)
            end

            if @additional_price_group.save
              flash.now[:notice] = "Save success" #text("update.success")
            else
              raise(ActiveRecord::Rollback)
              flash.now[:error] = text("errors")
            end
          end
          flash.now[:notice] = "Save success" #text("update.success")
        end
      rescue => e
        flash.now[:error] = text("errors.save")
      end
    return render :edit

#    end
#    redirect_to facility_instrument_additional_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})
  end

  def edit
    @params = params.permit(:facility_id, :instrument_id, :additional_price_policy_id, :id)

    return redirect_to facility_instrument_additional_price_policies_path if @params[:additional_price_policy_id].blank? && @params[:id].blank?

#    @addition_price_name = @params[:name]

    additional_price_group_id = @params[:id]

    @additional_price_group = AdditionalPriceGroup.find_by(id: additional_price_group_id)

    @price_policy_date = @params[:additional_price_policy_id]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    raise ActiveRecord::RecordNotFound if @price_policies.blank?
    @additional_price_policies = get_current_additional_price_policies(@price_policies, @params[:id])

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?

    raise ActiveRecord::RecordNotFound if @additional_price_policies.blank?

    return render :edit
  end

  def delete

    @params = params.permit(:facility_id, :instrument_id, :additional_price_policy_id, :id)
    return redirect_to facility_instrument_additional_price_policies_path if @params[:additional_price_policy_id].blank? && @params[:id].blank?

    @additional_price_group_id = @params[:id]
    @price_policy_date = @params[:additional_price_policy_id]

#    if @price_policy_date.to_date <= Date.today
#      flash[:error] = text("errors.remove_active_policy")
#      return  redirect_to facility_instrument_additional_price_policies_path
#    end

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    raise ActiveRecord::RecordNotFound unless @price_policies.length > 0

    @additional_price_policies = get_current_additional_price_policies(@price_policies, @params[:id])

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?
    destroy(@additional_price_policies, @additional_price_group_id)
    redirect_to facility_instrument_additional_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})

  end

  def destroy(additional_price_policies, additional_price_group_id)
    ActiveRecord::Base.transaction do

      begin
        @date = Time.zone.now

        additional_price_policies.each do |additional_price_policy|

          return if additional_price_policy.id.nil?

          deleted_by = current_user.id
          @a = AdditionalPricePolicy.find(additional_price_policy.id.to_i)
          unless @a.update( :deleted_at => @date, :deleted_by => deleted_by)
            raise(ActiveRecord::Rollback)
          end

          @additional_price_group = AdditionalPriceGroup.find(additional_price_group_id)
          unless @additional_price_group.update( :deleted_at => @date, :deleted_by => deleted_by)
            raise(ActiveRecord::Rollback)
          end
          flash.now[:notice] = text("destroy.success")
        end
      end
    rescue => e
      flash.now[:error] = text("errors.save")
      return render :edit
    end
  end

  private
  def init_product
    id_param = params.except(:facility_id).keys.detect { |k| k.end_with?("_id") }
    class_name = id_param.sub(/_id\z/, "").camelize
    @product = current_facility.products
                               .of_type(class_name)
                               .find_by!(url_name: params[id_param])
  end

  def get_new_additional_price_policies(price_policies)
    price_policies.map do |price_policy|
      new_additional_price_policy(price_policy)
    end
  end

  def get_current_additional_price_policies(price_policies, id)
    price_policies.map do |price_policy|
      current_additional_price_policies(price_policy, id)
    end

  end

  def current_additional_price_policies(price_policy, additional_price_group_id)
    @additional_price_policies = AdditionalPricePolicy.where("price_policy_id = ? AND additional_price_group_id = ? AND deleted_at IS NULL", price_policy.id, additional_price_group_id).order(additional_price_group_id: :asc, price_policy_id: :asc)
    "AdditionalPricePolicy".constantize.new(
      id: @additional_price_policies.length > 0 ? @additional_price_policies[0].id : nil,
      #name: name,
      #product_price_group_id: @additional_price_policies.product_price_group_id,
      cost: @additional_price_policies.length > 0 ? @additional_price_policies[0].cost : 0,
      price_policy_id: price_policy.id
    )
  end

  def new_additional_price_policy(price_policy)
    "AdditionalPricePolicy".constantize.new(
      #name: "",
      cost: 0,
      price_policy_id: price_policy.id
    )
  end

  def save
    ActiveRecord::Base.transaction do
      @additional_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
    end
  end
end
