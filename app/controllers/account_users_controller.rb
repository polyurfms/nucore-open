# frozen_string_literal: true

class AccountUsersController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_account

  load_and_authorize_resource
  
  def initialize
    @active_tab = "accounts"
    super
  end

  # GET /accounts/:account_id/account_users/user_search
  def user_search
  end

  def create_user
    # account_id = params[:account_id];
    # @facility = Facility.joins("INNER JOIN account_facility_joins on account_facility_joins.facility_id = facilities.id INNER JOIN accounts ON account_facility_joins.account_id = accounts.id WHERE accounts.id = #{account_id}")
  end

  # POST /facilities/:facility_id/users
  def insert_user
    @user = username_lookup(params[:username])
    # authorize! :create, @user
    if @user.nil?
      flash[:error] = text("netid_not_found")
      redirect_to account_account_users_path
    elsif @user.persisted?
      flash[:error] = text("user_already_exists", username: @user.username)
      redirect_to account_account_users_path
    elsif @user.save
      LogEvent.log(@user, :create, current_user)
      @user.create_default_price_group!
      save_user_success(@user)

      # Add Payment Source
      @account_user = AccountUser.grant(@user, 'Purchaser', @account, by: session_user)
      if @account_user.persisted?
        LogEvent.log(@account_user, :create, current_user)
        flash[:notice] = text("create.success", user: @user.full_name, account_type: @account.type_string)
        redirect_to account_account_users_path(@account)
      else
        flash.now[:error] = text("create.error", user: @user.full_name, account_type: @account.type_string)
        render :new
      end
    else
      flash[:error] = text("create.error", message: @user.errors.full_messages.to_sentence)
      redirect_to account_account_users_path
    end
  end

  def save_user_success(user)
    flash[:notice] = text("create.success")
    if session_user.manager_of?(current_facility)
      add_role = html("create.add_role", link: facility_facility_user_map_user_path(current_facility, user), inline: true)
      flash[:notice].safe_concat(add_role)
    end
    # Notifier.new_user(user: user, password: user.password).deliver_later
  end
  
  def add_user
    @user = username_lookup(params[:username_lookup])
    render layout: false
  end

  def service_username_lookup(username)
    LdapAuthentication::UserLookup.new.call(username)
  end

  def username_lookup(username)
    return nil if username.blank?
    username_database_lookup(username.strip) || service_username_lookup(username.strip)
  end

  def username_database_lookup(username)
    User.find_by("LOWER(username) = ?", username.downcase)
  end

  # GET /accounts/:account_id/account_users/new
  def new
    @user         = User.find(params[:user_id])
    @account_user = AccountUser.new
  end

  # POST /accounts/:account_id/account_users
  def create
    ## TODO add security
    @user = User.find(params[:user_id])
    @account_user = AccountUser.grant(@user, create_params[:user_role], @account, by: session_user)

    if @account_user.persisted?
      LogEvent.log(@account_user, :create, current_user)
      flash[:notice] = text("create.success", user: @user.full_name, account_type: @account.type_string)
      redirect_to account_account_users_path(@account)
    else
      flash.now[:error] = text("create.error", user: @user.full_name, account_type: @account.type_string)
      render :new
    end
  end

  # DELETE /accounts/:account_id/account_users/:id
  def destroy
    ## TODO add security

    @account_user.deleted_by = session_user.id
    if @account_user.destroy
      LogEvent.log(@account_user, :delete, current_user)
      flash[:notice] = text("destroy.success")
    else
      flash[:error] = text("destroy.error")
    end
    redirect_to account_account_users_path(@account)
  end

  protected

  def create_params
    params.require(:account_user).permit(:user_role)
  end

  def init_account
    # @account = session_user.accounts.find(params[:account_id])
    @account = @acting_user.accounts.find(params[:account_id])
  end

  private

  def ability_resource
    @account
  end

end
