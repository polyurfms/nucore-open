# frozen_string_literal: true

class FacilityAccountsController < ApplicationController

  include AccountSuspendActions
  include SearchHelper
  include CsvEmailAction

  admin_tab     :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_current_facility
  before_action :init_account, except: :search_results
  before_action :build_account, only: [:new, :create]
  before_action :check_alert_threshold, only: [:update, :create]

  authorize_resource :account
  helper_method :is_allow_request


  layout "two_column"
  before_action { @active_tab = "admin_users" }

  # GET /facilties/:facility_id/accounts
  def index
    accounts = Account.with_orders_for_facility(current_facility)
    @accounts = accounts.paginate(page: params[:page])
  end

  # GET /facilties/:facility_id/accounts/:id
  def show
  end

  # GET /facilities/:facility_id/accounts/new
  def new
  end

  def allocation
    @account_users = @account.account_users
  end

  def funding_requests
    @account_users = @account.account_users
    @funding_request = FundingRequest.new
    @funding_request.request_type="LOCK_FUND_REQUEST"
    @funding_requests = @account.funding_requests.order(created_at: :desc)
  end

  def create_funding_request
    #puts "funding request update starts"
    @funding_requests = @account.funding_requests.order(created_at: :desc)

    fr_param = params[:funding_request]

    if is_allow_request
      creator = FundingRequestCreator.new(@account, session_user.id, params)
      if creator.save()
        redirect_to facility_account_funding_requests_path(current_facility, @account)
      else
        flash.now[:error] = creator.error.html_safe
        @funding_request = creator.funding_request
        render :funding_requests
      end
=begin
      if @funding_request.save
        flash[:notice] = "Save success" #text("update.success")
        if @account.type == "ChequeOrOtherAccount"
          if @funding_request.request_type == 'LOCK_FUND_REQUEST'
            @account.committed_amt = @account.committed_amt + @funding_request.debit_amt
          else
            @account.committed_amt = @account.committed_amt + @funding_request.credit_amt
          end
          @account.save
        end

        redirect_to facility_account_funding_requests_path(current_facility, @account)
      else
        #@input_amt = amt
        flash.now[:error]= @funding_request.errors.first[1]
        render :funding_requests
      end
=end

    else
      flash[:error] = I18n.t(".funding_requests.index.message.in_progress")
      redirect_to facility_account_funding_requests_path(current_facility, @account)
    end

  end

  def is_allow_request
    allow_request = true
    @account.funding_requests.each  do |at|
      if at.status == "PENDING_CHECK_FUND" or at.status == "PENDING_LOCK_FUND"
        allow_request = false
      end
    end
    return allow_request
  end

  def allocation_update

    au = params[:account_user]
    auv = au.values
    @id = params[:account_id]

    #load form field to model
    @account.assign_attributes(account_users_attributes: auv)
    if @account.save
      flash.now[:notice] = "Save success" #text("update.success")
    else
      flash.now[:error]= @account.errors.full_messages[0]

    end

    #load model for form display
    @account_users = @account.account_users
    render :allocation

  end

  def edit
    @profile = @user.profile.order("saved DESC").first
  end


  # POST /facilities/:facility_id/accounts
  def create
    # The builder might add some errors to base. If those exist,
    # we don't want to try saving as that would clear the original errors
    if @account.errors[:base].empty? && @account.save
      LogEvent.log(@account, :create, current_user)
      flash[:notice] = I18n.t("controllers.facility_accounts.create.success")
      redirect_to facility_user_accounts_path(current_facility, @account.owner_user)
    else
      render action: "new"
    end
  end



  # GET /facilities/:facility_id/accounts/:id/edit
  def edit
  end

  # PUT /facilities/:facility_id/accounts/:id
  def update
    @account = AccountBuilder.for(@account.class).new(
      account: @account,
      current_user: current_user,
      owner_user: @owner_user,
      params: params,
    ).update

    if @account.save
      LogEvent.log(@account, :update, current_user)
      flash[:notice] = I18n.t("controllers.facility_accounts.update")
      redirect_to facility_account_path
    else
      render action: "edit"
    end
  end

  def new_account_user_search
  end

  # GET/POST /facilities/:facility_id/accounts/search_results
  def search_results
    searcher = AccountSearcher.new(params[:search_term], scope: Account.for_facility(current_facility))
    if searcher.valid?
      @accounts = searcher.results

      respond_to do |format|
        format.html do
          @accounts = @accounts.paginate(page: params[:page])
          render layout: false
        end
        format.csv do
          yield_email_and_respond_for_report do |email|
            AccountSearchResultMailer.search_result(email, params[:search_term], SerializableFacility.new(current_facility)).deliver_later
          end
        end
      end
    else
      flash.now[:errors] = "Search terms must be 3 or more characters."
      render layout: false
    end
  end

  # GET /facilities/:facility_id/accounts/:account_id/members
  def members
  end

  # GET /facilities/:facility_id/accounts/:account_id/statements
  def statements
    @statements = Statement.for_facility(current_facility)
                           .where(account: @account)
                           .paginate(page: params[:page])
  end

  # GET /facilities/:facility_id/accounts/:account_id/statements/:statement_id
  def show_statement
    @statement = Statement.for_facility(current_facility)
                          .where(account: @account)
                          .find(params[:statement_id])

    respond_to do |format|
      format.pdf do
        @statement_pdf = StatementPdfFactory.instance(@statement, download: true)
        render "statements/show"
      end
    end
  end

  private

  def available_account_types
    @available_account_types ||= Account.config.account_types_for_facility(current_facility, :create).select do |account_type|
      current_ability.can?(:create, account_type.constantize)
    end
  end
  helper_method :available_account_types

  def current_account_type
    @current_account_type ||= if available_account_types.include?(params[:account_type])
                                params[:account_type]
                              else
                                available_account_types.first
                              end
  end
  helper_method :current_account_type

  def init_account
    if params.key? :id
      @account = Account.find params[:id].to_i
    elsif params.key? :account_id
      @account = Account.find params[:account_id].to_i
    end
  end

  def build_account
    raise CanCan::AccessDenied if current_account_type.blank?

    @owner_user = User.find(params[:owner_user_id])
    @account = AccountBuilder.for(current_account_type).new(
      account_type: current_account_type,
      facility: current_facility,
      current_user: current_user,
      owner_user: @owner_user,
      params: params,
    ).build
  end

  def check_alert_threshold

    render_page = false
    if(@account.type == "NufsAccount")
      if(params[:nufs_account][:alert_threshold].nil? || params[:nufs_account][:alert_threshold] == "" || params[:nufs_account][:alert_threshold].to_f < 0)
        flash[:error] = "Alert threshold must be equal to or larger than 0"
        render_page = true
      end
      @account.alert_threshold = params[:nufs_account][:alert_threshold].to_f
      free_balance = @account.free_balance
      
      if(params[:action].eql?('update'))
        if(@account.alert_threshold > free_balance)
          flash[:error] = "Free balance must be equal to or larger than alert threshold"
          render_page = true
        end
      end
      
    end

    if(render_page == true)
      if(params[:action].eql?('update'))
        render action: "edit"
      else
        render action: "new"
      end
       
    end
  end

end
