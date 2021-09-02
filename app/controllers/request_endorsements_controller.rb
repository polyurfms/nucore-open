class RequestEndorsementsController < ApplicationController

    customer_tab :all
    before_action :authenticate_user!
    before_action :check_acting_as

    def index    
        @count = User.check_academic_user_and_payment_source(session[:acting_user_id] || session_user[:id]).count
        @current_type = "request_endorsements"
        @request_endorsement = RequestEndorsement.where(user_id: session[:acting_user_id] || session_user[:id]).order(created_at: :desc)
        @can_request = true
        @request_endorsement.each do |request|
            @can_request =false if request.deleted_at.nil? && request.created_at.to_datetime + 1.days > Time.zone.now.to_datetime && (request.is_accepted.nil? || request.is_accepted == true)
        end
    end
    
    def make_request
        @supervisor =  User.find_by(email: params[:supervisor_id])
        @current_user = User.find(params[:request_endorsement_id])
        

        @request_endorsement = RequestEndorsement.where(user_id: @user_id).where("deleted_at IS NOT NULL AND DATE_FORMAT(created_at,'%Y-%m-%d %H:%i:%s') <= DATE_FORMAT(:created_at,'%Y-%m-%d %H:%i:%s')", created_at: (Time.zone.now + 1.days).strftime("%Y-%m-%d %H:%M:%S"))
        return "/" unless session[:acting_user_id] || session_user[:id] == current_user.id  || @request_endorsement.count == 0 || @supervisor.length == 0 
        update(@current_user, @supervisor)

        redirect_to request_endorsements_path()
    end

    def update(requester, supervisor)
        @date = Time.zone.now
        @token = generateToken(requester.username, supervisor.username, @date)
        @request_endorsement = RequestEndorsement.new
        @request_endorsement.user_id = requester.id
        @request_endorsement.token = @token  
        @request_endorsement.supervisor = supervisor.username
        @request_endorsement.created_at = @date
        @request_endorsement.updated_at = @date
        @request_endorsement.created_by = session[:acting_user_id] || session_user[:id]
        @request_endorsement.updated_by = session[:acting_user_id] || session_user[:id]

        if @request_endorsement.save
            RequsetEndorsementMailer.notify(supervisor, requester, @request_endorsement).deliver_later
            flash[:notice] = "Success"
        else
            flash[:error] = "Fail to make request"
        end
    end
    
    def generateToken(user_netid, supervisor_netid, date)
        @token = ""
        @date = date.strftime("%Y%m%d%H%M")
        @random_num = rand.to_s[2..11] ;
        @user_netid = user_netid.ljust(10, '#') 
        @supervisor_netid = supervisor_netid.ljust(10, '#')
        @token = @date + @random_num + @user_netid + @supervisor_netid

        @aes = AES.new
        @result = @aes.aes_encrypt(@token)
        
        return @result
    end

    def destroy    
        @request_endorsement_id = params[:id] || ""

        @request_endorsement = RequestEndorsement.find(@request_endorsement_id.to_i)
        return redirect_to request_endorsements_path() if @request_endorsement.is_accepted
        
        if @request_endorsement_id.blank?
            flash.now[:error] = "An error occurred."
        else
            ActiveRecord::Base.transaction do
                begin
                    @date = Time.zone.now
                    deleted_by = current_user.id
                    unless @request_endorsement.update( :deleted_at => @date, :deleted_by => deleted_by)
                        raise(ActiveRecord::Rollback)
                    end
    
                    flash[:notice] = "The request has been removed successfully."
                end
            rescue => e
                flash.now[:error] = "An error occurred."
            end
        end
        
        redirect_to request_endorsements_path()
    end

    def service_username_lookup(username)
        LdapAuthentication::UserLookup.new.call(username)
      end
    
      def username_lookup(username)
        return nil if username.blank?
        # || service_username_lookup(username.strip)
        username_database_lookup(username.strip) 
      end
    
      def username_database_lookup(username)
        User.find_by("LOWER(username) = ?", username.downcase)
      end
end
