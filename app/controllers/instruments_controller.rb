# frozen_string_literal: true

class InstrumentsController < ProductsCommonController

  customer_tab :show, :public_schedule, :public_list
  admin_tab :create, :new, :edit, :index, :manage, :update, :manage, :schedule
  before_action :store_fullpath_in_session, only: [:index, :show]
  before_action :set_default_lock_window, only: [:create, :update]
  before_action :public_flag_checked?, only: [:public_schedule]
  before_action :check_supervisor, only: [:show]
  before_action :check_phone, only: [:show]

  # public_schedule does not require login
  skip_before_action :authenticate_user!, only: [:public_list, :public_schedule]
  skip_authorize_resource only: [:public_list, :public_schedule]
  skip_before_action :init_product, only: [:instrument_statuses, :public_list]

  def public_flag_checked?
    facility_id = params[:facility_id] || params[:id]
    case
    when facility_id.blank?
      authenticate_user!
    else
      @facility = Facility.find_by(url_name: facility_id);
      unless @facility.show_instrument_availability?
        if session_user.blank?
          authenticate_user!
        end
      end
    end
  end

  # GET /facilities/:facility_id/instruments/list
  def public_list
    @instruments = Instrument.active.in_active_facility.order(:name).includes(:facility)
    @active_tab = "home"
    render layout: "application"
  end

  # GET /facilities/:facility_id/instruments/:instrument_id
  def show
    instrument_for_cart = InstrumentForCart.new(@product)
    # TODO: Remove this instance variable-not used anywhere but tests
    # @add_to_cart = instrument_for_cart.purchasable_by?(acting_user, session_user)

    @add_to_cart = false
    if(has_delegated && session[:is_selected_user] == true)
      @add_to_cart = true
    else
      @add_to_cart = instrument_for_cart.purchasable_by?(acting_user, session_user)
    end

    if @add_to_cart
      redirect_to new_facility_instrument_single_reservation_path(current_facility, @product)
    elsif instrument_for_cart.error_path
      redirect_to instrument_for_cart.error_path, notice: instrument_for_cart.error_message
    else
      flash.now[:notice] = instrument_for_cart.error_message if instrument_for_cart.error_message
      render layout: "application"
    end
  end

  # GET /facilities/:facility_id/instruments/:instrument_id/schedule
  def schedule
    @admin_reservations =
      @product
      .reservations
      .admin_and_offline
      .ends_in_the_future
      .order(:reserve_start_at)
  end

  def public_schedule
    # show schedule if user have access right
    if @product.can_be_used_by?(session_user)
      render layout: "application"
    else
      # redirect to product page if user not in access list and need access right to see the schedule
      if @product.show_details_with_access
        redirect_to facility_instrument_path(@facility , @product), notice: "Schedule view restricted for authorised personnel."
      else # show schedule if user do not have access right and allow to see product without access right
        render layout: "application"
      end
    end
  end

  def set_default_lock_window
    if params[:instrument][:lock_window].blank?
      params[:instrument][:lock_window] = 0
    end
  end

  def instrument_statuses
    @instrument_statuses = InstrumentStatusFetcher.new(current_facility).statuses
    render json: @instrument_statuses
  end

  # GET /facilities/:facility_id/instruments/:instrument_id/switch
  def switch
    raise ActiveRecord::RecordNotFound unless params[:switch] && (params[:switch] == "on" || params[:switch] == "off")

    begin
      relay = @product.relay
      status = true

      if SettingsHelper.relays_enabled_for_admin?
        relay.call_relay_user_info("", "Admin", "", "", "")
        if (params[:switch] == "off")
          @product.reservations.current_in_use.each do |res|
            res.end_reservation!
          end
        end
        status = (params[:switch] == "on" ? relay.activate : relay.deactivate)
      end
      @status = @product.instrument_statuses.create!(is_on: status)
    rescue => e
      logger.error "ERROR: #{e.message}"
      @status = InstrumentStatus.new(instrument: @product, error_message: e.message)
      # raise ActiveRecord::RecordNotFound
    end
    render json: @status
  end

  private

  def check_supervisor
    if session[:had_supervisor] == 0
      if session_user.is_normal_user?
        return redirect_to '/no_supervisor_or_phone'
      end
    end
  end

  def check_phone
    if !session_user.nil? && session_user.phone.nil?
      if session_user.is_normal_user?
        return redirect_to '/no_supervisor_or_phone'
      end
    end
  end
end
