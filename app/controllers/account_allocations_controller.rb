# frozen_string_literal: true

class AccountAllocationsController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  before_action :check_acting_as
#  before_action :init_account_allocation

  def initialize
    @active_tab = "accounts"
    super
  end

  # GET /accounts/:account_id/account_users/new
  def new
    puts "new start"
    @account = session_user.accounts.find(params[:account_id])
  end

  def show
  end

  # GET /accounts/:account_id/account_users/edit
  def edit
  end

  # GET /accounts/:account_id/account_user_allocations
  def index
    @account = session_user.accounts.find(params[:account_id])

    @account_users ||= AccountUser.where(account_id: @account.id, deleted_at: nil).where.not(user_role: "Owner")

    if @account.can_allocate?
      render :new
    else
      redirect_to account_path(@account)
    end


  end

  def update_allocation
    puts "update allocation"

    au = params[:account_user]
    auv = au.values
    @id = params[:account_id]

    #load account info before update attribute
    @account = session_user.accounts.find(params[:account_id])

    #load form field to model
    @account.assign_attributes(account_users_attributes: auv)
    if @account.save
      flash.now[:notice] = "Save success" #text("update.success")
    else
      flash.now[:error] = text("errors")

    end

    #load model for form display
    @account_users = @account.account_users


    render :new
  end

  protected

end
