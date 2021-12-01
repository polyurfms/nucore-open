class RequestEndorsementsController < ApplicationController

    customer_tab :all
    before_action :authenticate_user!
    before_action :check_acting_as

    def index
        @user_id = session[:acting_user_id] || session_user[:id]
        @count = User.check_academic_user_and_payment_source(session[:acting_user_id] || session_user[:id]).count
        @current_type = "request_endorsements"
        @request_endorsement = RequestEndorsement.where(user_id: session[:acting_user_id] || session_user[:id]).order(created_at: :desc)
        @can_request = true

        @result = Array.new
        @request_endorsement.each do |request|
            @can_request =false if request.deleted_at.nil? && request.created_at.to_datetime + 1.days > Time.zone.now.to_datetime && (request.is_accepted.nil? || request.is_accepted == true)
        end
    end

    def make_request
        @user_id = session[:acting_user_id] || session_user[:id]
        @current_user = User.find(params[:request_endorsement_id])
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @email = params[:email]
        @dept_abbrev =  params[:dept_abbrev]
        @supervisor =  params[:username]
        @is_academic = params[:is_academic]
        
        @request_endorsement = RequestEndorsement.where(user_id: @user_id).where("deleted_at IS NOT NULL AND DATE_FORMAT(created_at,'%Y-%m-%d %H:%i:%s') <= DATE_FORMAT(:created_at,'%Y-%m-%d %H:%i:%s')", created_at: (Time.zone.now + 1.days).strftime("%Y-%m-%d %H:%M:%S"))
        return "/" unless session[:acting_user_id] || session_user[:id] == current_user.id  || @request_endorsement.count == 0 || @supervisor.length == 0
        update(@current_user, @supervisor, @email, @first_name, @last_name, @dept_abbrev, @is_academic)

        redirect_to request_endorsements_path()
    end

    def update(requester, supervisor, email, first_name, last_name, dept_abbrev, is_academic)
        @date = Time.zone.now
        @token = generateToken(requester.username, supervisor, @date)
        @request_endorsement = RequestEndorsement.new
        @request_endorsement.user_id = requester.id
        @request_endorsement.token = @token
        @request_endorsement.supervisor = supervisor
        @request_endorsement.created_at = @date
        @request_endorsement.updated_at = @date
        @request_endorsement.created_by = session[:acting_user_id] || session_user[:id]
        @request_endorsement.updated_by = session[:acting_user_id] || session_user[:id]
        @request_endorsement.email = email
        @request_endorsement.first_name = first_name
        @request_endorsement.last_name = last_name
        @request_endorsement.dept_abbrev = dept_abbrev
        @request_endorsement.is_academic = is_academic

        if @request_endorsement.save
            RequsetEndorsementMailer.notify(email, requester, @request_endorsement, first_name, last_name).deliver_later
            flash[:notice] = "Success, supervisor endorsement request sent."
        else
            flash[:error] = "Error, failed to send supervisor endorsement."
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
        supervisor = User.find_by(username:  @request_endorsement.email)
        user = User.find(@request_endorsement.user_id)
        RequsetEndorsementMailer.remove_notify(@request_endorsement.email, user, @request_endorsement, supervisor.first_name, supervisor.last_name).deliver_later
        redirect_to request_endorsements_path()
    end
end
