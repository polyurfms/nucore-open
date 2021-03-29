# frozen_string_literal: true

class UserProfileController < ApplicationController

  customer_tab :all
  before_action :authenticate_user!
  before_action :check_acting_as

  before_action :authenticate_user!, only: :edit_current
  before_action :no_user_allowed, only: [:edit, :update]
  
  before_action { @active_tab = "user_profile" }

  def no_user_allowed
    if current_user
      redirect_to action: :edit_current
      return false
    end
  end

  def edit_current
    @user = current_user
    @current_type = "my_profile"
    @count = User.check_academic_user_and_payment_source(@user.id).count

  end

  def update_mobile 
    @phone = user_params

    if !@phone["phone"].blank?
      @user = current_user

      if @user.update(phone: @phone["phone"])
        flash[:notice] = "Successful"
      else
        flash[:error] = "failed"
      end
      
      redirect_to edit_current_profile_path()
    else 
      flash[:error] = "Please input mobile no."
      redirect_to edit_current_profile_path()
    end
    
  end

  
  def user_params
    params.require(:user).permit(:phone)
  end

end
