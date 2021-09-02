

class NoSupervisorsController < ApplicationController

    include AZHelper

    customer_tab :all
    before_action :authenticate_user!
    before_action :check_acting_as
    
    def index
      
      if session[:had_supervisor] == 1 || session[:had_supervisor].blank? || session_user.administrator?
        redirect_to '/facilities'
      end
      
      @is_requested = false
        msg = ""
        session[:had_supervisor] = session_user.has_supervisor? ? 1 : 0
        if session[:had_supervisor] == 0
          @request_endorsement = RequestEndorsement.where(user_id: session[:acting_user_id] || session_user[:id]) 
          @request_endorsement.each do |request|
            @is_requested = true if request.deleted_at.nil? && request.created_at.to_datetime + 1.days > Time.zone.now.to_datetime && (request.is_accepted.nil? || request.is_accepted == true)
          end
        end

      flash.now[:error] = "No Supervisor. Please go to 'My Profile' -> 'Request Endorsements' to make endorsement " unless @is_requested

    end
    
  end
  