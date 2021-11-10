class ApiController < ApplicationController

  skip_authorize_resource only: [:place_smart_card, :get_next_reservation]
  before_action :authenticate, :only => [:place_smart_card, :get_next_reservation]
  http_basic_authenticate_with :name => "postmail@test.com", :password => "12345678" 
  skip_before_action  :verify_authenticity_token 
  skip_authorize_resource only: [:supervisor_endorsement, :supervisor_endorsement_submit]

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
          @user = User.find_by(card_number: cardno)

          # Avoid another user end reservation
          unless @product.nil? && @user.nil? 
              @facility = Facility.find_by(id: @product[0].facility_id)
              relation = @user.order_details
              
              in_progress = relation.with_in_progress_reservation
              @order_details = in_progress + relation.with_upcoming_reservation_by_product(@product[0].id)

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

              
              is_on = check_current_relay_status(@facility)
                            
              unless is_on
                if begin_reservation_list.length > 0
                  # Relay status is turn on 
                  begin_reservation_list.collect do |res|
                    begin_reservation(res)
                  end
                end
              else
                # Relay status is turn off                 
                if end_reservation_list.length > 0
                  # Relay status is turn on 
                  end_reservation_list.collect do |res|
                    end_reservation(res)
                  end
                end
              end
          end
          render json: {"status": "success", "message": nil}
        rescue => e
          render json: {"status": "failed", "message": "Cannot find reservation"}
        end
          
      else
        render json: {"status": "failed", "message": "Some parameter is nil"} 
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
      @status = @action.eql?("true") ? "Approved" : "Rejected"

      ActiveRecord::Base.transaction do
        begin
          @date = Time.zone.now
          request_endorsement = @request_endorsement[0]
          update_request_endorsemets(request_endorsement, @date, @action)

          @to = @user.email + ", " + request_endorsement.email


          RequsetEndorsementMailer.confirm_notify(@to, request_endorsement, @status).deliver_later
        rescue ActiveRecord::RecordInvalid => e
          raise ActiveRecord::Rollback
        end
      end
    render :supervisor_submitted
    end
  end

  private
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

    creator = SupervisorCreator.create(user, request_endorsement.last_name, request_endorsement.first_name, request_endorsement.email, request_endorsement.supervisor, request_endorsement.dept_abbrev, request_endorsement.is_academic)
    unless creator.save()
      raise(ActiveRecord::Rollback)
    end
  end


end
