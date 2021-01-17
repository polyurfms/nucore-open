# frozen_string_literal: true

class UserDelegationsController < ApplicationController

  customer_tab :all
  before_action :authenticate_user!
  before_action :check_acting_as
  # authorize_resource class: NUCore
  
  before_action { @active_tab = "user_delegations" }
  
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
      end    
      
      session[:is_selected_user] = true
    end
    
    redirect_to '/'
  end

  def index
    @user_delegation = UserDelegation.new
    @user_id = session_user[:id]
    @assigned_list = UserDelegation.find_by ("delegator = #{session_user[:id]} AND deleted_at IS NULL " )
    @is_assigned = !@assigned_list.nil?

    count = User.check_academic_user_and_payment_source(@user_id).count
    unless(count > 0)
      redirect_to '/'
    end

  end

  def create
    @delegate_info = user_delegation_params
    @user_delegation = UserDelegation.create(@delegate_info)
 
    delegatee= User.find_by(username: @delegate_info["delegatee"])
    delegator = User.find(session_user[:id])

    LogEvent.log(@user_delegation, :create, delegator)

    unless (@user_delegation.delegator.nil?)
      if @user_delegation.save
        UserDelegationMailer.notify(delegatee: delegatee, delegator: delegator).deliver_later
        flash[:notice] = text("#{@user_delegation.delegatee} delegated")
      else 
        flash[:notice] = text("#{@user_delegation.delegatee} could not be delegated")
      end 
    end
    redirect_to action: :index
  end

  def destroy

    begin
      user_delegation = UserDelegation.find_by delegator: session_user[:id], id: params[:id].to_i
      delegator = User.find(session_user[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "User not found!"
    else
      unless (user_delegation.delegator.nil?)
        user_delegation.deleted_at = Time.zone.now
        user_delegation.deleted_by = session_user[:id]
        if user_delegation.save
          LogEvent.log(user_delegation, :delete, delegator)
          flash[:notice] = "Delegatee #{user_delegation.delegatee} removed"
        else 
          flash[:error] = "Delegatee #{ser_delegation.delegatee} could not be removed"
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
