# frozen_string_literal: true

class AdditionPricePoliciesController < ApplicationController
    
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

    # @current_price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: parse_usa_date(@date_range_start)).joins(:addition_price_policy).order(name: :asc)
    
    @current_price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: parse_usa_date(@date_range_start)).order(id: :asc)

    @current_start_date = @current_price_policies.first.try(:start_date) unless @current_price_policies.nil?
    @current_expires_date = @current_price_policies.first.try(:expire_date) unless @current_price_policies.nil?

    @search_id = @current_price_policies.select(&:can_purchase?).map do |price_policy|
      price_policy.id
    end

    @current_addition_price_policies = AdditionPricePolicy.where("price_policy_id IN (?)", @search_id).where("deleted_at IS NULL").order(name: :asc, price_policy_id: :asc)
    render "addition_price_policies/index"
  end


  def add
    @params = params.permit(:facility_id, :instrument_id, :addition_price_policy_id) 
    
    return redirect_to facility_instrument_addition_price_policies_path if @params[:addition_price_policy_id].blank?
    
    @price_policy_date = @params[:addition_price_policy_id]
    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    
    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?

    raise ActiveRecord::RecordNotFound if @price_policies.blank?
    @addition_price_policies = get_new_addition_price_policies(@price_policies)
    raise ActiveRecord::RecordNotFound if @addition_price_policies.blank?
  end

  def create
    @params = params.permit(:addition_price_name, :startdate, :facility_id, :instrument_id)  
    return redirect_to facility_instrument_addition_price_policies_path if @params[:startdate].blank?
   
    @addition_price_name = @params[:addition_price_name] || ""
    @price_policy_date = @params[:startdate]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    @addition_price_policies = get_new_addition_price_policies(@price_policies)

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?
    

    @date = Time.zone.now
    @addition_price_policies.each do |addition_price_policy|
      addition_price_policy.name = @addition_price_name
      addition_price_policy.cost = params["price_policy_#{addition_price_policy.price_policy.id}"][:cost]
      addition_price_policy.created_at = @date
      addition_price_policy.updated_at = @date
      addition_price_policy.created_by = current_user.id
    end
    
    @search_price_polic_id = @price_policies.map do |price_policy|
      price_policy.id
    end

    @duplcation = AdditionPricePolicy.where("price_policy_id IN (?) AND name = ? AND deleted_at IS NULL", @search_price_polic_id, @addition_price_name).order(name: :asc, price_policy_id: :asc).count

    if @addition_price_name.eql?("") || @duplcation > 0
      flash.now[:error] = text("errors.null_name") if @addition_price_name.eql?("") 
      flash.now[:error] = text("errors.duplcation_name") if @duplcation > 0
      return render :add
    else
      begin
        ActiveRecord::Base.transaction do
          @addition_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
        end
      rescue => e
        flash.now[:error] = text("errors.save")
        return render :add
      end
    end
    redirect_to facility_instrument_addition_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})
    # redirect_to facility_instrument_addition_price_policies_path(@params[:facility_id] , @params[:instrument_id])
  end

  def update
    # @params_info = params.permit(:facility_id, :instrument_id) 
    @params = params[:addition_price_policy]

    return redirect_to facility_instrument_addition_price_policies_path if @params[:startdate].blank?
   
    @addition_price_name = @params[:addition_price_name] || ""
    @price_policy_date = @params[:startdate]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    @addition_price_policies = get_new_addition_price_policies(@price_policies)

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?
    
    @addition_price_policies.each do |addition_price_policy|
      addition_price_policy.id = params["price_policy_#{addition_price_policy.price_policy.id}"][:id]
      addition_price_policy.name = @addition_price_name
      addition_price_policy.cost = params["price_policy_#{addition_price_policy.price_policy.id}"][:cost]
    end
    
    @search_price_polic_id = @price_policies.map do |price_policy|
      price_policy.id
    end

    @search_addition_price_policies_id = @addition_price_policies.map do |addition_price_policies|
      params["price_policy_#{addition_price_policies.price_policy.id}"][:id]
    end

    @duplcation = AdditionPricePolicy.where("price_policy_id IN (?) AND name = ? AND deleted_at IS NULL AND id NOT IN (?) ", @search_price_polic_id, @addition_price_name, @search_addition_price_policies_id).order(name: :asc, price_policy_id: :asc).count
    
    if @addition_price_name.eql?("") || @duplcation > 0
      flash.now[:error] = text("errors.null_name") if @addition_price_name.eql?("") 
      flash.now[:error] = text("errors.duplcation_name") if @duplcation > 0
      return render :edit
    else
      begin
        ActiveRecord::Base.transaction do
          
          @date = Time.zone.now

          @addition_price_policies.each do |addition_price_policy|
            id = params["price_policy_#{addition_price_policy.price_policy.id}"][:id]
            name = @addition_price_name
            cost = params["price_policy_#{addition_price_policy.price_policy.id}"][:cost]

            @a = AdditionPricePolicy.find(id.to_i)
            unless @a.update( :name => name, :cost => cost, :updated_at => @date)
              raise(ActiveRecord::Rollback)
            end
          end
        end
      rescue => e
        flash.now[:error] = text("errors.save")
        return render :edit
      end
    end
    redirect_to facility_instrument_addition_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})
  end

  def edit
    @params = params.permit(:facility_id, :instrument_id, :addition_price_policy_id, :name) 
    
    return redirect_to facility_instrument_addition_price_policies_path if @params[:addition_price_policy_id].blank? && @params[:name].blank?
    
    @addition_price_name = @params[:name]
    @price_policy_date = @params[:addition_price_policy_id]

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    raise ActiveRecord::RecordNotFound if @price_policies.blank?
    @addition_price_policies = get_current_addition_price_policies(@price_policies, @params[:name])

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?
    
    raise ActiveRecord::RecordNotFound if @addition_price_policies.blank?

    return render :edit
  end

  def delete


    @params = params.permit(:facility_id, :instrument_id, :addition_price_policy_id, :name) 
    return redirect_to facility_instrument_addition_price_policies_path if @params[:addition_price_policy_id].blank? && @params[:name].blank?

    @addition_price_name = @params[:name]
    @price_policy_date = @params[:addition_price_policy_id]
    if @price_policy_date.to_date <= Date.today
      flash[:error] = text("errors.remove_active_policy")
      return  redirect_to facility_instrument_addition_price_policies_path 
    end

    @price_policies = @product.price_policies.where("start_date <= :now AND expire_date > :now", now: @price_policy_date.to_datetime)
    raise ActiveRecord::RecordNotFound unless @price_policies.length > 0
    @addition_price_policies = get_current_addition_price_policies(@price_policies, @params[:name])

    @current_start_date = @price_policies.first.try(:start_date) unless @price_policies.nil?
    @current_expires_date = @price_policies.first.try(:expire_date) unless @price_policies.nil?
    destroy(@addition_price_policies)
    redirect_to facility_instrument_addition_price_policies_path(params[:facility_id] , params[:instrument_id], search: {date_range_start:  format_usa_date(@price_policy_date)})

  end

  def destroy(addition_price_policies)
    begin
      ActiveRecord::Base.transaction do
        
        @date = Time.zone.now
        addition_price_policies.each do |addition_price_policy|

          return if addition_price_policy.id.nil?

          deleted_by = current_user.id
          @a = AdditionPricePolicy.find(addition_price_policy.id.to_i)
          unless @a.update( :deleted_at => @date, :deleted_by => deleted_by)
            raise(ActiveRecord::Rollback)
          end
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

  def get_new_addition_price_policies(price_policies)
    price_policies.map do |price_policy|
      new_addition_price_policy(price_policy)
    end
  end

  def get_current_addition_price_policies(price_policies, name)
    price_policies.map do |price_policy|
      current_addition_price_policies(price_policy, name)
    end
  end

  def current_addition_price_policies(price_policy, name)
    @addition_price_policies = AdditionPricePolicy.where("price_policy_id = ? AND name = ? AND deleted_at IS NULL", price_policy.id, name).order(name: :asc, price_policy_id: :asc)

    "AdditionPricePolicy".constantize.new(
      id: @addition_price_policies.length > 0 ? @addition_price_policies[0].id : nil,
      name: name,
      cost: @addition_price_policies.length > 0 ? @addition_price_policies[0].cost : 0,
      price_policy_id: price_policy.id
    )
  end

  def new_addition_price_policy(price_policy)
    "AdditionPricePolicy".constantize.new(
      name: "",
      cost: 0,
      price_policy_id: price_policy.id
    )
  end

  def save
    ActiveRecord::Base.transaction do
      @addition_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
    end
  end
end
