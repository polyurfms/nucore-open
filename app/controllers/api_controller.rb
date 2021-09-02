class ApiController < ApplicationController

  skip_authorize_resource only: [:supervisor_endorsement, :supervisor_endorsement_submit]
 
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

    # @user = get_user(@user_netid).sub('#', '')
    # @supervisor = get_user(@supervisor_netid).sub('#', '')
    @user = get_user("testing@example.com")
    @supervisor = get_user("ppi123@example.com")    

    return true if @user.nil? || @supervisor.nil?
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
          update_request_endorsemets(@supervisor, @request_endorsement, @date, @action)

          @to = @user.email + ", " + @supervisor.email
          RequsetEndorsementMailer.confirm_notify(@to, @supervisor, @status).deliver_later
        rescue ActiveRecord::RecordInvalid => e
          raise ActiveRecord::Rollback
        end
      end    
      redirect_to facilities_path
    end    
  end

  private
  def get_user(netid)
    User.find_by("LOWER(username) = ?", netid.downcase)
  end

  def update_request_endorsemets(supervisor, request_endorsement, date, action)
    if request_endorsement.update(is_accepted: action, updated_by: supervisor.id, updated_at: date)
      update_supervisor_of_requester(@user, @supervisor, @date) if action.eql?("true") 
    else  
      raise(ActiveRecord::Rollback)
    end
  end

  def update_supervisor_of_requester(user, supervisor, date)
    creator = SupervisorCreator.create(user, supervisor.last_name, supervisor.first_name, supervisor.email)
    unless creator.save()
      raise(ActiveRecord::Rollback)
    end
  end 


end
