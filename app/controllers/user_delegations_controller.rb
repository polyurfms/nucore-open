# frozen_string_literal: true

class UserDelegationsController < ApplicationController

  customer_tab :all
  before_action :authenticate_user!
  before_action :check_acting_as
  # authorize_resource class: NUCore

  before_action { @active_tab = "user_profile" }

  # def initialize
  #   @active_tab = "user_delegations"
  #   super
  # end

  def switchUser
    if session[:is_selected_user].nil? || session[:is_selected_user] == false
      @user  = User.find_by(username: session_user[:username])
      unless @user.nil?
        # @delegate_list = User.joins("LEFT JOIN user_delegations ON user_delegations.delegator = users.id WHERE user_delegations.delegatee LIKE '#{session_user[:username]}' or users.id = #{session_user[:id]}")
        # @delegate_list = User.joins("LEFT JOIN user_delegations ON user_delegations.delegator = users.id WHERE user_delegations.deleted_at IS NULL AND (user_delegations.delegatee LIKE '#{session_user[:username]}' or users.id = #{session_user[:id]} ) ORDER BY FIELD(users.id, #{session_user[:id]}) DESC , users.username ")

        @delegate_list1 = User.where(id: session_user[:id])
        @delegate_list2 = User.joins("LEFT JOIN user_delegations ON user_delegations.delegator = users.id WHERE user_delegations.deleted_at IS NULL AND user_delegations.delegatee LIKE '#{session_user[:username]}' ORDER BY users.username ")

        @delegate_list = @delegate_list1 + @delegate_list2
      end

      unless  @delegate_list.size > 1
        session[:is_selected_user] = true
        redirect_to '/facilities'
      end
    else
      redirect_to '/'
    end
  end

  def switch_to
    if session[:is_selected_user].nil? || session[:is_selected_user] == false
      unless session_user.id.to_i == params[:user_delegation_id].to_i
        session[:acting_user_id] = params[:user_delegation_id]
        session[:acting_ref_url] = "/facilities"
        session[:facility_agreement_list]= nil
      end

      session[:is_selected_user] = true
    end

    redirect_to '/'
  end

  def index
    @user_delegation = UserDelegation.new
    @user_id = session[:acting_user_id] || session_user[:id]
#    @user_id = session_user[:id]
    @current_type = "my_delegation"

    # @assigned_list = UserDelegation.find_by ("delegator = #{session_user[:id]} AND deleted_at IS NULL " )
    @assigned_list ||= UserDelegation.where(delegator: session[:acting_user_id] || session_user[:id], deleted_at: nil)

    @is_assigned = false
    @is_assigned = true if @assigned_list.count > 0

    @count = User.check_academic_user_and_payment_source(@user_id).count

    unless(@count > 0)
      redirect_to '/'
    end
  end

  def create
    @user_id = session_user[:id]
    @count ||= User.check_academic_user_and_payment_source(@user_id).count
    @current_type = "my_delegation"

    @delegate_info = user_delegation_params

    # delegatee = service_username_lookup(@delegate_info["delegatee"].strip)
    delegatee= User.find_by(username: @delegate_info["delegatee"].strip)
    # delegator = User.find(session_user[:id])
    delegator = User.find( session[:acting_user_id] || session_user[:id])

    has_error = true

    if (delegatee.nil? || delegator.nil?)
      # flash[:error] = text("#{@delegate_info["delegatee"].strip} cannot be found") if delegatee.nil?
      flash[:error] = text(" User not found ") if delegatee.nil?
    elsif (delegatee.username.eql?(delegator.username))
      flash[:error] = text(" Cannot assign yourself ")
    else
      @user_delegation_list ||= UserDelegation.where(delegatee: delegatee.username, delegator: delegator.id, deleted_at: nil).count

      if (@user_delegation_list > 0)
        flash[:error] = text("#{delegatee.username} has been assigned")
      elsif (!delegatee.user_type.eql?("Staff"))
        flash[:error] = "Invalid user"
      else
        @user_delegation = UserDelegation.create(@delegate_info)
        if @user_delegation.save
          LogEvent.log(@user_delegation, :create, delegator)
          UserDelegationMailer.notify(delegatee.first_name + " " + delegatee.last_name, delegator.email,  delegator.first_name+ " " + delegator.last_name).deliver_later
          flash[:notice] = text("#{@user_delegation.delegatee} assigned")
          has_error = false
          redirect_to action: :index
        else
          flash[:error] = text("#{delegatee.username} could not be assigned")
        end
      end
    end

    if has_error
      @assigned_list ||= UserDelegation.where(delegator:  session[:acting_user_id] || session_user[:id], deleted_at: nil)
      @user_id =  session[:acting_user_id] || session_user[:id]
      @is_assigned ||= true if @assigned_list.count > 0
      @user_delegation = UserDelegation.new
      @user_delegation.delegatee = @delegate_info["delegatee"].strip
      puts "has errorrrr//////////"
      render action: :index
    end
  end

  def service_username_lookup(username)
    LdapAuthentication::UserLookup.new.call(username)
  end

  def destroy
     begin
      user_delegation = UserDelegation.find_by delegator:  session[:acting_user_id] || session_user[:id], id: params[:id].to_i
      delegator = User.find( session[:acting_user_id] || session_user[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "User not found!"
    else
      unless (user_delegation.delegator.nil?)
        user_delegation.deleted_at = Time.zone.now
        user_delegation.deleted_by =  session[:acting_user_id] || session_user[:id]
        if user_delegation.save
          LogEvent.log(user_delegation, :delete, delegator)
          flash[:notice] = "Assistant #{user_delegation.delegatee} was removed."
        else
          flash[:error] = "Assistant #{user_delegation.delegatee} could not be removed"
        end
      end
    end
    redirect_to action: :index

    # begin
    #   user_delegation = UserDelegation.find_by delegator: session_user[:id], id: params[:id].to_i
    #   delegator = User.find(session_user[:id])
    # rescue ActiveRecord::RecordNotFound
    #   flash[:error] = "User not found!"
    # else
    #   user_delegation.destroy
    #   LogEvent.log(user_delegation, :delete, delegator)

    #   if user_delegation.destroyed?
    #     flash[:notice] = "Delegatee #{user_delegation.delegatee} removed"
    #   else
    #     flash[:error] = "Delegatee #{ser_delegation.delegatee} could not be removed"
    #   end
    # end
    # redirect_to action: :index
  end


  private

  def user_delegation_params
    params.require(:user_delegation).permit(:delegatee, :delegator)
  end

end
