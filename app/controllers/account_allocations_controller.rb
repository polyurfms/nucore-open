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
    
    @account_user_import = AccountUser.new
    # if @account.can_allocate?
    #   render :new
    # else
    #   redirect_to account_path(@account)
    # end
    
    render :new
  end

  def update_allocation
    puts "update allocation"
    
    #load account info before update attribute
    @account = session_user.accounts.find(params[:account_id])

    if (!@account.allows_allocation.nil? && @account.allows_allocation == true)
      au = params[:account_user]
      auv = au.values
      @id = params[:account_id]
  
  
      #load form field to model
      @account.assign_attributes(account_users_attributes: auv)
      if @account.save
        flash.now[:notice] = "Save success" #text("update.success")
      else
        flash.now[:error] = text("errors")
      end
    end
    
    #load model for form display
    @account_users = @account.account_users

    render :new
  end

  def export_user 
    @account = Account.find(params[:account_id])
    unless @account.nil? 
      @csv = Reports::PaymentSourceUserImport.new(nil, @account, session_user)
      respond_to do |format|
        format.html
        format.csv { send_data @csv.export!, filename: "payment_source_user_import_template_#{Date.today}.csv" }
        # format.html
      end
    end
  end

  def import_user 

    begin
      raise "Please upload a valid import file" unless params[:account_user].present?

      @account = session_user.accounts.find(params[:account_id])
  
      if (!@account.allows_allocation.nil? && @account.allows_allocation == true)
        @account = Account.find(params[:account_id])
        unless @account.nil? 
          @csv = Reports::PaymentSourceUserImport.new(params[:account_user][:file], @account, session_user)
          @csv.import("Update")
          flash.now[:notice] = "Save success" 
        end
      end
    rescue => e
      import_exception_alert(e)
    end
    
    redirect_to account_account_allocations_path
  end

  def import_exception_alert(exception)
    Rails.logger.error "#{exception.message}\n#{exception.backtrace.join("\n")}"
    flash[:error] = import_exception_message(exception)
  end
  
  def import_exception_message(exception)
    I18n.t("controllers.order_imports.create.error", error: exception.message)
  end

  protected

end
