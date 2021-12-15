class ApiController < ApplicationController

  skip_authorize_resource only: [:supervisor_endorsement, :supervisor_endorsement_submit, :room_access]
  http_basic_authenticate_with :name => Settings.basic_authenticate.username, :password => Settings.basic_authenticate.password , only: [:room_access]

  before_action :authenticate, :only => [:place_smart_card, :get_next_reservation]
  skip_before_action  :verify_authenticity_token

  def room_access
    ip = request.ip
    if !Settings.basic_authenticate.room_access.ip.present? || ip.eql?(Settings.basic_authenticate.room_access.ip)
      result = Array.new
      # reservations = Reservation.where("reserve_end_at <= :now ", now: Time.current.end_of_day)
      #reservations = Reservation.where("reserve_start_at >= :start AND reserve_end_at <= :end AND order_detail_id IS NOT NULL", start: Time.current.beginning_of_day, end: Time.current.end_of_day).room_interface_enabled
      reservations = Reservation.room_interface
      if reservations.count > 0
        reservations.each do |r|
          start_datetime ||= r.reserve_start_at
          end_datetime ||= r.reserve_end_at
          uid ||= r.order_detail.order.user.card_number
          room_no ||= r.product.room_no
          unless start_datetime.nil? && start_datetime.blank? && end_datetime.nil? && end_datetime.blank? && uid.nil? && uid.blank? && room_no.nil? && room_no.blank?
            result << {start_datetime: start_datetime, end_datetime: end_datetime, uid: uid, room_no: room_no}
          end
        end

        unless result.empty?
          @csv = Reports::DoorAccessExport.new(result)
          send_data(@csv.export!, filename: "booking_#{Time.current.strftime("%Y-%m-%d %H:%M:%S")}.txt")
        end
      end
    end
    # head :ok
  end

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
        ip = request.ip
        @relay = Relay.find_by(ip: ip)
        return true
        # aes = ScRelayConnect::AES.new()
        # aes.aes_decrypt(username).eql?(@relay.username) && aes.aes_decrypt(password).eql?(@relay.password)
    end
  end

  def get_next_reservation
    relayIp = params[:relayIp] || ""
    # @product = Product.joins("INNER JOIN relays on relays.instrument_id  = products.id  WHERE relays.ip = '#{relayIp}'")

    # @orderDetail = OrderDetail.next_reservation(@product[0].id)
  end

  def place_smart_card
    cardno = params[:cardno] || ""
    relayIp = params[:relayIp] || ""
    cardPresentTime = params[:cardPresentTime] || ""

    unless cardno.blank? && relayIp.blank? && !relayIp.eql?(request.ip)
      begin

        @product = Product.joins("INNER JOIN relays on relays.instrument_id  = products.id  WHERE relays.ip = '#{relayIp}'")
        @relay = Relay.find_by(ip: relayIp)
        # @user = User.find_by(card_number: cardno)
        @user = User.where("concat('60',card_number) like substring(:cardno,1,8) or card_number like substring(:cardno,1,9) or card_number = :cardno",  cardno: cardno)

        unless @user.nil? || @product.nil?
          @facility = Facility.find_by(id: @product[0].facility_id)
          relation = @user.first.order_details

          #check if upcoming booking ready to start
          #ready_to_start_reservation = relation.ready_to_start_reservation_by_product(@product[0].id)

          #if ready_to_start_reservation.empty?
          in_progress = relation.with_in_progress_reservation
          @order_details = in_progress + relation.with_upcoming_reservation_by_product(@product[0].id)
          #@order_details = in_progress
          #@order_details = in_progress + relation.with_upcoming_reservation_by_product(@product[0].id)
          #else
          #   @order_details = ready_to_start_reservation
          #end

          begin_reservation_list = []
          end_reservation_list = []

          @order_details.collect do |od|

            status = notice_for_reservation od.reservation
            if status.eql?("start")
              begin_reservation_list << od.reservation
            # elsif status.eql?("end")
            else
              end_reservation_list << od.reservation
            end
          end

          # if begin list is not empty, begin reservation
          if begin_reservation_list.length > 0
            begin_reservation_list.collect do |res|
              begin_reservation(res)
            end
          else
            if end_reservation_list.length > 0
              end_reservation_list.collect do |res|
                end_reservation(res)
              end
            end
          end
          render json: {"status": "success", "message":  begin_reservation_list.length > 0 || end_reservation_list.length > 0 ? "Is_success" : nil}
        else
          raise "error"
        end

        # render json: {"status": "success", "message": nil}
      rescue => e
        logger.error "ERROR: #{e.message}"
        render json: {"status": "failed", "message": "Cannot find reservation"}
      end
    else
      render json: {"status": "failed", "message": "Some parameter is nil"}
    end
  end



  def checkCurrentReservation
    netId = params[:netId] || ""
    relayIp = params[:relayIp] || ""

    is_on = false
    unless relayIp.blank? && !relayIp.eql?(request.ip)
      @product = Product.joins("INNER JOIN relays on relays.instrument_id  = products.id  WHERE relays.ip = '#{relayIp}'")
      @relay = Relay.find_by(ip: relayIp)
      if @product.length > 0  && @relay.length > 0
        result = Hash.new
        # result["outlet"] = @relay.outlet
        # result["name"] = @product.first.name
        result["name"] = @product.first.abbreviation || ""
        if netId.blank?
          result["in_process"] = ""
          render json: {"status": "success", "message": result}
        else
          @user = User.find_by(username: netId)
          unless @user.nil?
            @facility = Facility.find_by(id: @product[0].facility_id)
            relation = @user.order_details

            in_progress = relation.with_in_progress_reservation
            @order_details = in_progress + relation.with_upcoming_reservation_by_product(@product[0].id)

            @order_details.collect do |od|

              status = notice_for_reservation od.reservation
              unless status.eql?("start")
                is_on = true
              end
            end

            result["in_process"] = is_on
            render json: {"status": "success", "message": result}
          else
            render json: {"status": "success", "message": "No ressult"}
          end
        end
      else
        render json: {"status": "failed", "message": "No ressult"}
      end

    else
      render json: {"status": "failed", "message": "Some parameter is nil"}
    end
  end

  def supervisor_endorsement
    @token = params[:token] || ""
    redirect_to facilities_path if @token.blank?
    has_error = supervisor_endorsement_validation(@token)

    if has_error
      redirect_to facilities_path
    else
      render :supervisor_endorsement
    end
  end


  def supervisor_endorsement_submit
    @token = params[:token] || ""
    @action = params[:is_approval] || ""

    return redirect_to facilities_path if @token.blank? || @action.blank?
    has_error = supervisor_endorsement_validation(@token)


    if has_error
      redirect_to facilities_path
    else
      @status = @action.eql?("true") ? "Approved" : "Declined"

      ActiveRecord::Base.transaction do
        begin
          @date = Time.zone.now
          supervisor  = @request_endorsement[0]
          update_request_endorsemets(supervisor, @date, @action)

          # @to = @user.email + ", " + request_endorsement.email
          @to = @user.email 

          RequestEndorsementMailer.confirm_notify(@to, supervisor, @user, @status).deliver_later
        rescue ActiveRecord::RecordInvalid => e
          raise ActiveRecord::Rollback
        end
      end
    render :supervisor_submitted
    end
  end

  private
  def notice_for_reservation(reservation)
    return unless reservation
    "end" if reservation.can_switch_instrument_off?
    "start" if reservation.can_switch_instrument_on?
  end

  def check_current_relay_status(facility)
      @instrument_statuses = InstrumentStatusFetcher.new(@facility).statuses
      return @instrument_statuses[0].is_on
  end

  def begin_reservation(reservation)
    ReservationInstrumentSwitcher.new(reservation).switch_on!
  end

  def end_reservation(reservation)
    unless reservation.other_reservation_using_relay?
      ReservationInstrumentSwitcher.new(reservation).switch_off!
    end
  end



  def supervisor_endorsement_validation(token)
    @request_endorsement = RequestEndorsement.where(token: token).where("deleted_at IS NULL and is_accepted IS NULL")

    return true unless @request_endorsement.length > 0
    # return redirect_to facilities_path unless @request_endorsement.length > 0

    @can_accept = false
    @can_accept = true if @request_endorsement[0].deleted_at.nil? && @request_endorsement[0].created_at.to_datetime + 1.days > Time.zone.now.to_datetime && @request_endorsement[0].is_accepted.nil?
    return true unless @can_accept
    # return redirect_to facilities_path unless @can_accept
    @aes = AES.new
    @result = @aes.aes_decrypt(token)
    @date = @result.slice(0,12)
    @user_netid = @result.slice(22,10)
    @supervisor_netid= @result.slice(32,10)

    return true unless @date.eql?(@request_endorsement[0].created_at.to_datetime.strftime("%Y%m%d%H%M"))
    # return redirect_to facilities_path unless @date.eql?(@request_endorsement[0].created_at.to_datetime.strftime("%Y%m%d%H%M"))

    @user = get_user(@user_netid.gsub('#', ''))
    # @supervisor = get_user(@supervisor_netid).sub('#', '')
    # @user = get_user("testing@example.com")
    # @supervisor = get_user("ppi123@example.com")

    return true if @user.nil?
    # return redirect_to facilities_path if @user.nil? || @supervisor.nil?

    false
  end

  def get_user(netid)
    User.find_by("LOWER(username) = ?", netid.downcase)
  end

  def update_request_endorsemets(request_endorsement, date, action)
    if request_endorsement.update(is_accepted: action, updated_by: request_endorsement.user_id, updated_at: date)
      update_supervisor_of_requester(@user, request_endorsement, @date) if action.eql?("true")
    else
      raise(ActiveRecord::Rollback)
    end
  end

  def update_supervisor_of_requester(user, request_endorsement, date)

    creator = SupervisorCreator.update(user, request_endorsement.last_name, request_endorsement.first_name, request_endorsement.email, request_endorsement.supervisor, request_endorsement.dept_abbrev, request_endorsement.is_academic, 1)
    unless creator.save()
      raise(ActiveRecord::Rollback)
    end
  end


end
