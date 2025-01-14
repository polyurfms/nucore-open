# frozen_string_literal: true

class FacilityAccountUsersController < ApplicationController

  admin_tab     :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_current_facility
  before_action :init_account

  load_and_authorize_resource class: AccountUser

  layout "two_column"

  helper_method :current_owner?

  def initialize
    @active_tab = "admin_billing"
    super
  end

  # GET /facilities/:facility_id/accounts/:account_id/account_users/user_search
  def user_search
    @account = Account.find(params[:account_id])
  end

  # GET /facilities/:facility_id/accounts/:account_id/account_users/new
  def new
    @user = User.find(params[:user_id])
    role = current_owner? ? AccountUser::ACCOUNT_OWNER : AccountUser::ACCOUNT_PURCHASER
    @account_user = AccountUser.new(user_role: role)
  end

  # POST /facilities/:facility_id/accounts/:account_id/account_users
  def create
    @user = User.find(params[:user_id])
    # @account_user = AccountUser.grant(@user, create_params[:user_role], @account, by: session_user)
    @account_user = AccountUser.create_member(@user, create_params[:user_role], @account, by: session_user)

    if @account_user.persisted?
      flash[:notice] = text("create.success", user: @user.full_name, account_type: @account.type_string)
      LogEvent.log(@account_user, :create, current_user)
      Notifier.user_update(account: @account, user: @user, created_by: session_user).deliver_later
      redirect_to facility_account_members_path(current_facility, @account)
    else
      flash.now[:error] = text("create.error", user: @user.full_name, account_type: @account.type_string)
      render(action: "new")
    end
  end

  # DELETE /facilities/:facility_id/accounts/:account_id/account_users/:id
  def destroy
    @account = Account.find(params[:account_id])
    @account_user = @account.account_users.find(params[:id])

    @account_user.deleted_by = session_user.id

    if @account_user.destroy
      LogEvent.log(@account_user, :delete, current_user)
      flash[:notice] = text("destroy.success")
    else
      flash[:error] = text("destroy.error")
    end
    redirect_to facility_account_members_path(current_facility, @account)
  end

  def import_user
    begin
      process_payment_source_user_import!
    rescue => e
      import_exception_alert(e)
    end
    
    redirect_to facility_account_members_path(current_facility, @account)
  end

  private

  def init_account
    @account = Account.find(params[:account_id])
  end

  def create_params
    params.require(:account_user).permit(:user_role)
  end

  def current_owner?
    @account.owner_user == @user
  end

  def import_payment_source_uer!
    @account = Account.find(params[:account_id])
    unless @account.nil? 
      @csv = Reports::PaymentSourceUserImport.new(params[:account_user][:file], @account, session_user)
      @csv.import("Insert")
      flash.now[:notice] = "Save success" 
    end
    
  end
  
  def process_payment_source_user_import!
    raise "Please upload a valid import file" unless params[:account_user].present?
    import_payment_source_uer!
  end

  def import_exception_alert(exception)
    Rails.logger.error "#{exception.message}\n#{exception.backtrace.join("\n")}"
    flash[:error] = import_exception_message(exception)
  end
  
  def import_exception_message(exception)
    I18n.t("controllers.order_imports.create.error", error: exception.message)
  end


end
