class ApiController < ApplicationController

  skip_authorize_resource only: [:supervisor_endorsement, :supervisor_endorsement_submit, :room_access]
  http_basic_authenticate_with :name => Settings.basic_authenticate.username, :password => Settings.basic_authenticate.password , only: [:room_access]

  def room_access
    ip = request.ip
    if ip.eql?(Settings.basic_authenticate.room_access.ip) 
      result = Array.new
      # reservations = Reservation.where("reserve_end_at <= :now", now: Time.current.end_of_day)
      reservations = Reservation.where("reserve_start_at >= :start AND reserve_end_at <= :end", start: Time.current.beginning_of_day, end: Time.current.end_of_day)
      if reservations.count > 0
        reservations.each do |r|
          start_datetime ||= r.reserve_start_at
          end_datetime ||= r.reserve_end_at
          uid ||= "123" 
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
    head :ok
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
