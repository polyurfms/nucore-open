# frozen_string_literal: true

class AccountsController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_account, only: [:show, :user_search, :transactions, :suspend, :unsuspend, :edit, :update]
  before_action :check_alert_threshold, only: [:update]
  include AccountSuspendActions
  load_and_authorize_resource only: [:show, :user_search, :transactions, :suspend, :unsuspend]

  def initialize
    @active_tab = "accounts"
    super
  end

  # GET /accounts
  def index
    # @account_users = session_user.account_users
    # @administered_order_details_in_review = current_user.administered_order_details.in_review
    # @account_users = @acting_user.account_users
    
    @is_delegated = false;    
    if(!session[:acting_user_id].nil? && !session[:acting_user_id].eql?(""))
      @is_delegated = true
    end
    @account_users = @acting_user.account_users.joins("INNER JOIN accounts on accounts.id = account_users.account_id").order(account_number: :ASC)
    @administered_order_details_in_review = @acting_user.administered_order_details.in_review
  end

  # GET /accounts/1
  def show
  end

  # GET /accounts/1/user_search
  def user_search
    check_delegations if !has_delegated
    render(template: "account_users/user_search")
  end

  # GET /accounts/1/allocation
  def allocation
    render(template: "accounts/allocation")
  end

  # GET /accounts/1/edit
  def edit
    #@account = Account.find(params[:id] || params[:account_id])
  end

  # PUT /accounts/:account_id/
  def update
    id = params[:id]
    @account = AccountBuilder.for(@account.class).new(
      account: @account,
      current_user: current_user,
      owner_user: current_user,
      params: params,
    ).update
    
    @account.valid?
    @account.errors.full_messages

    if @account.save!
      flash[:notice] = I18n.t("controllers.facility_accounts.update")
    end

    redirect_to account_path
  end

  protected

  def init_account
    @account = Account.find(params[:id] || params[:account_id])
  end

  private

  def check_alert_threshold
    if(@account.type == "NufsAccount")
      if(params[:nufs_account][:alert_threshold].nil? || params[:nufs_account][:alert_threshold] == "" || params[:nufs_account][:alert_threshold].to_f < 0)
        flash[:error] = "Alert threshold must be equal to or larger than 0"
        redirect_to account_path
      end
      @account.alert_threshold = params[:nufs_account][:alert_threshold].to_f
      free_balance = @account.free_balance
      # if(@account.alert_threshold > free_balance)
      #   flash[:error] = "Free balance must be equal to or larger than alert threshold"
      #   redirect_to account_path
      # end
    end
  end

  def ability_resource
    @account
  end
  
  def account_params
    params.require(AccountBuilder.for(type)).permit(:allows_allocation)
  end
end
