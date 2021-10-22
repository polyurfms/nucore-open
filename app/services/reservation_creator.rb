# frozen_string_literal: true

class ReservationCreator

  include DateHelper

  attr_reader :order, :order_detail, :params, :error

  delegate :merged_order?, :instrument_only_order?, to: :status_q

  def initialize(order, order_detail, params)
    @order = order
    @order_detail = order_detail
    @params = params
  end

  def save(session_user, delegatee_id = 0)
    if !@order_detail.bundled? && params[:order_account].blank?
      @error = I18n.t("controllers.reservations.create.no_selection")
      return false
    end

    reservation_param = params[:reservation]

    if reservation_param[:reserve_end_min].blank? || reservation_param[:reserve_start_min].blank?
      @error = I18n.t("controllers.reservations.create.invalid_start_end_time")
      return false
    end

    # Check additional price policy exist in current period    
    unless params[:additional_price_policy].blank?
      is_exist_addition_item = getAdditionalPricePolicy(params[:additional_price_policy], reservation_param[:reserve_start_date])
      unless is_exist_addition_item
        price_policy_id = AdditionalPricePolicy.joins("INNER JOIN additional_price_groups ON additional_price_policies.additional_price_group_id = additional_price_groups.id").where("additional_price_groups.id = :id", id: params[:additional_price_policy]).joins(:price_policy).uniq.pluck :price_policy_id
        start_date = PricePolicy.where("id IN (?)", price_policy_id).where("price_policies.start_date > :now", now: format_usa_date(reservation_param[:reserve_start_date])).order("price_policies.start_date ASC").uniq.pluck :start_date 
        addition_item = AdditionalPriceGroup.find(params[:additional_price_policy])
        @error = "#{addition_item.name} start on #{format_usa_date(start_date.first)}"
        return false
      end
    end
    
    Reservation.transaction do
      begin
        update_order_account
        @order.dept_abbrev = session_user.dept_abbrev

        #@order_detail.additional_price_policy_name = params[:additional_price_policy] unless params[:additional_price_policy].blank?

        unless params[:additional_price_policy].blank?
          @order_detail.additional_price_group_id = params[:additional_price_policy]
        end
        # merge state can change after call to #save! due to OrderDetailObserver#before_save
        to_be_merged = @order_detail.order.to_be_merged?
        raise ActiveRecord::RecordInvalid, @order_detail unless reservation_and_order_valid?(session_user)
        validator = OrderPurchaseValidator.new(@order_detail)
        raise ActiveRecord::RecordInvalid, @order_detail if validator.invalid?

        save_reservation_and_order_detail(session_user)


        # When allows_allocation is true, free_balance must more than that stimated_cost
        not_enough = ""

        if(session_user.administrator? != true)
          @account = Account.find(@order_detail.order.account_id.to_i)
          if(@account.allows_allocation == true)
            @account_user = AccountUser.find_by(account_id: @order_detail.account_id, deleted_at: nil, user_id: delegatee_id == 0 ? session_user .id : delegatee_id)

            if(@account_user.user_role != "Owner")
              if(@account_user.quota_balance < 0)
                not_enough = "Payment source insufficient fund"
                raise ActiveRecord::Rollback
              end
            end
          end

          if(@account.free_balance < 0)
            not_enough = "Payment source insufficient fund"
            raise ActiveRecord::Rollback
          end
        end

        if to_be_merged
          # The purchase_order_path or cart_path will handle the backdating, but we need
          # to do this here for merged reservations.
          backdate_reservation_if_necessary(session_user)
          @success = :merged_order
        elsif @order.order_details.one?
          @success = :instrument_only_order
        else
          @success = :default
        end
      rescue ActiveRecord::RecordInvalid => e
        @error = e.message
        raise ActiveRecord::Rollback
      rescue StandardError => e
        msg = e.message
        unless not_enough == ""
          msg = not_enough
        end
        @error = I18n.t("orders.purchase.error", message: msg).html_safe
        # @error = I18n.t("orders.purchase.error", message: e.message).html_safe
        raise ActiveRecord::Rollback
      end
    end


  end

  def reservation
    return @reservation if defined?(@reservation)
    @reservation = @order_detail.build_reservation
    @reservation.assign_attributes(reservation_create_params)
    @reservation.assign_times_from_params(reservation_create_params)
    @reservation.select_additional_price_policy = params[:additional_price_policy] unless params[:additional_price_policy].blank?
    @reservation
  end

  private

  def reservation_create_params
    params.require(:reservation)
          .except(:reserve_end_date, :reserve_end_hour, :reserve_end_min, :reserve_end_meridian)
          .permit(:reserve_start_date, :reserve_start_hour, :reserve_start_min, :reserve_start_meridian, :duration_mins, :note, :reference_id, :project_id)
          .merge(product: @order_detail.product)
  end

  def update_order_account
    return if params[:order_account].blank?

    account = Account.find(params[:order_account].to_i)
    # If the account has changed, we need to re-do validations on the order. We're
    # only saving the changes if the reservation is part of a cart. Otherwise, we
    # just modify the object in-memory for redisplay.
    if account != @order.account
      @order.invalidate if @order.persisted?
      @order.account = account
      @order.save! if @order.persisted?
    end
  end

  def backdate_reservation_if_necessary(session_user)
    facility_ability = Ability.new(session_user, @order.facility, self)
    @order_detail.backdate_to_complete!(@reservation.reserve_end_at) if facility_ability.can?(:order_in_past, @order) && @reservation.reserve_end_at < Time.zone.now
  end

  def reservation_and_order_valid?(session_user)
    reservation.valid_as_user?(session_user) && order_detail.valid_as_user?(session_user)
  end

  def save_reservation_and_order_detail(session_user)
    reservation.save_as_user!(session_user)
    order_detail.actual_adjustment = 0
    order_detail.assign_estimated_price(reservation.reserve_end_at)
    order_detail.save_as_user!(session_user)
  end

  def status_q
    ActiveSupport::StringInquirer.new(@success.to_s)
  end

  def getAdditionalPricePolicy(additional_price_policy_id, start_datetime)
    addition_price_policy_list = AdditionalPricePolicy.joins("INNER JOIN additional_price_groups ON additional_price_policies.additional_price_group_id = additional_price_groups.id").where("additional_price_groups.id = :id", id: additional_price_policy_id)
    .joins(:price_policy).where("start_date <= :now AND expire_date > :now", now: parse_usa_date(start_datetime)).uniq.count
    result = addition_price_policy_list > 0 ? true : false
    result
  end

end
