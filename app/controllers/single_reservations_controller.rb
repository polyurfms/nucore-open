class SingleReservationsController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  load_resource :facility, find_by: :url_name
  load_resource :instrument, through: :facility, find_by: :url_name
  before_action :build_order
  before_action { @submit_action = facility_instrument_single_reservations_path }



  def new
    @reservation = NextAvailableReservationFinder.new(@instrument).next_available_for(current_user, acting_user)
    @reservation.order_detail = @order_detail

    authorize! :new, @reservation

    unless @instrument.can_be_used_by?(acting_user)
      flash[:notice] = text("controllers.reservations.acting_as_not_on_approval_list")
    end
    set_windows
    render "reservations/new"
  end

  def create
    creator = ReservationCreator.new(@order, @order_detail, params)
    @reservation = creator.reservation
    @account = Account.find_by("id = #{params["order_account"].to_i} AND expires_at >= '#{@reservation.reserve_end_at}'")

    set_windows

    if(!@account.nil?)
      if creator.save(session_user, session[:acting_user_id] || 0)
        # @reservation = creator.reservation
        authorize! :create, @reservation
        flash[:notice] = I18n.t("controllers.reservations.create.success")
        redirect_to purchase_order_path(@order, params.permit(:send_notification))
      else
        # @reservation = creator.reservation
        @error = "Validation failed: "
        flash.now[:error] = creator.error.html_safe unless creator.error == @error
        # set_windows
        render "reservations/new"
      end
    else
      flash.now[:error] = I18n.t("controllers.reservations.create.null_payment_source") if params["order_account"].to_i == 0
      flash.now[:error] = I18n.t("controllers.reservations.create.expires_at") unless params["order_account"].to_i == 0
      # set_windows
      render "reservations/new"
    end
  end

  private

  def ability_resource
    @reservation
  end

  def build_order
    @order = Order.new(
      user: acting_user,
      facility: current_facility,
      created_by: session_user.id,
    )
    @order_detail = @order.order_details.build(
      product: @instrument,
      quantity: 1,
      created_by: session_user.id,
    )
  end

  def set_windows
    @additional_price_policy = @order_detail.product.price_policies.get_additional_price_policy_list
    # @select_additional_price_policy = params[:additional_price_policy] if params[:additional_price_policy].nil?
    @select_additional_price_policy = @reservation.select_additional_price_policy? unless @reservation.select_additional_price_policy?.nil?
    @reservation_window = ReservationWindow.new(@reservation, current_user)
  end

end
