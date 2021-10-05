class ApiController < ApplicationController

  skip_authorize_resource only: [:place_smart_card, :get_next_reservation]
  before_action :authenticate, :only => [:place_smart_card, :get_next_reservation]
  http_basic_authenticate_with :name => "postmail@test.com", :password => "12345678" 
  skip_before_action  :verify_authenticity_token 

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
end
