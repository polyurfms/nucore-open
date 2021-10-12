# frozen_string_literal: true

class OrderManagement::OrderDetailsController < ApplicationController

  include OrderDetailFileDownload

  before_action :authenticate_user!

  load_resource :facility, find_by: :url_name
  load_resource :order, through: :facility
  load_resource :order_detail, through: :order

  helper_method :edit_disabled?

  before_action :authorize_order_detail, except: %i(sample_results template_results)
  before_action :load_accounts, only: [:edit, :update]
  before_action :load_order_statuses, only: [:edit, :update]

  admin_tab :all

  # GET /facilities/:facility_id/orders/:order_id/order_details/:id/manage
  def edit
    @active_tab = "admin_orders"
    render layout: false if modal?
  end

  # PUT /facilities/:facility_id/orders/:order_id/order_details/:id/manage
  def update
    @active_tab = "admin_orders"
    @order_detail.additional_price_group_id = params[:additional_price_policy]
    
    is_exist_addtion_item = check_addition_item()
    if is_exist_addtion_item
      updater = OrderDetails::ParamUpdater.new(@order_detail, user: session_user, cancel_fee: params[:with_cancel_fee] == "1")
      if updater.update_attributes(params[:order_detail] || empty_params)
        flash[:notice] = text("update.success")
        if @order_detail.updated_children.any?
          flash[:notice] = text("update.success_with_auto_scaled")
          flash[:updated_order_details] = @order_detail.updated_children.map(&:id)
        end
        if modal?
          head :ok
        else
          redirect_to [current_facility, @order]
        end
      else
        flash.now[:error] = text("update.error")
        render :edit, layout: !modal?, status: 406
      end
    else 
      price_policy_id = AdditionalPricePolicy.joins("INNER JOIN additional_price_groups ON additional_price_policies.additional_price_group_id = additional_price_groups.id")
      .where("additional_price_groups.id = :id", id: params[:additional_price_policy]).joins(:price_policy).uniq.pluck :price_policy_id
      start_date = PricePolicy.where("id IN (?)", price_policy_id).where("price_policies.start_date > :now", now: format_usa_date(params[:order_detail][:reservation][:actual_start_date])).order("price_policies.start_date ASC").uniq.pluck :start_date 
      @additional_error = "Save Error: The addition item start on #{format_usa_date(start_date.first)}"
      render :edit, layout: !modal?, status: 406
    end
    
  end

  # GET /facilities/:facility_id/orders/:order_id/order_details/:id/pricing
  def pricing
    @order_detail.additional_price_group_id = params[:additional_price_policy]
    checker = OrderDetails::PriceChecker.new(@order_detail)
    @prices = checker.prices_from_params(params[:order_detail] || empty_params, params[:additional_price_policy]|| "")

    render json: @prices.to_json
  end

  # GET /facilities/:facility_id/orders/:order_id/order_details/:id/files
  def files
    @files = @order_detail.stored_files.sample_result.order(:created_at)
    render layout: false if modal?
  end

  # POST /facilities/:facility_id/orders/:order_id/order_details/:id/remove_from_journal
  def remove_from_journal
    OrderDetailJournalRemover.remove_from_journal(@order_detail)

    flash[:notice] = text("remove_from_journal.notice")
    if modal?
      head :ok
    else
      redirect_to [current_facility, @order]
    end
  end

  private

  def modal?
    request.xhr?
  end
  helper_method :modal?

  def ability_resource
    @order_detail
  end

  def authorize_order_detail
    authorize! :update, @order_detail
  end

  def load_accounts
    @available_accounts = @order_detail.available_accounts.to_a
    @available_accounts << @order.account unless @available_accounts.include?(@order.account)
  end

  def load_order_statuses
    return if @order_detail.reconciled?

    if @order_detail.complete?
      @order_statuses = [OrderStatus.complete, OrderStatus.canceled]
      @order_statuses << OrderStatus.reconciled if @order_detail.can_reconcile?
    elsif @order_detail.order_status.root == OrderStatus.canceled
      @order_statuses = OrderStatus.canceled.self_and_descendants.for_facility(current_facility)
    else
      @order_statuses = OrderStatus.non_protected_statuses(current_facility)
    end
  end

  def edit_disabled?
    @order_detail.in_open_journal? || @order_detail.reconciled?
  end

  def check_addition_item
    unless params[:additional_price_policy].blank?
      actual_start_date = parse_usa_date(params[:order_detail][:reservation][:actual_start_date], "#{params[:order_detail][:reservation][:actual_start_hour]}:#{params[:order_detail][:reservation][:actual_start_min].to_s.rjust(2, '0')} #{params[:order_detail][:reservation][:actual_start_meridian]}")
      addition_price_policy_list = AdditionalPricePolicy.joins("INNER JOIN additional_price_groups ON additional_price_policies.additional_price_group_id = additional_price_groups.id")
        .where("additional_price_groups.id = :id", id: params[:additional_price_policy])
        .joins(:price_policy).where("start_date <= :now AND expire_date > :now", now: actual_start_date).uniq


        is_exist_addition_item = addition_price_policy_list.count > 0 ? true : false
        
        unless is_exist_addition_item
          return false
        end
    end

    return true
  end

end
