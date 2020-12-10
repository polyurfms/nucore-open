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

  authorize_resource :account

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
    puts "allocation"
    @account_users = @account.account_users
  end

  def allocation_update
    puts "[allocation_update][Start]"

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
=begin
    accountUsersJson = (params[:account_user])
    indexValue = 1

    # get allocation_sum
    allocation_sum = 100000.1

    inputSum = 0.0

    isValid = true

    message = ""

    if !accountUsersJson.nil?
      accountUsersJson.each do |au|
        inputAllocationAmt = 0
        if !inputAllocationAmt.nil? || !au[indexValue][:allocation_amt].empty?
          inputAllocationAmt = au[indexValue][:allocation_amt].to_f
        end


        if inputAllocationAmt < 0
          isValid = false
          message = "Error : Allocation must be a positive number!"
        end
        inputSum += inputAllocationAmt
      end

      if !@account.allows_allocation && isValid
        isValid = false
        message = "Error : The allocation is not active "
      end

      if  inputSum > allocation_sum && isValid
        isValid = false
        message = "Error : The allocation must be less than budget amount. "
      end


      if isValid
        accountUsersJson.each do |au|
          acountUserUpdate = AccountUser.find_by(id:au[indexValue][:id])
          if au[indexValue][:allocation_amt].nil? || au[indexValue][:allocation_amt].empty?
            acountUserUpdate.allocation_amt = 0
          else
            acountUserUpdate.allocation_amt = au[indexValue][:allocation_amt]
          end
          acountUserUpdate.save
        end
        message  = "Allocation update"
      end

    else
      isValid = false
      message = "Error : No members in payment sources!"
    end


    if isValid
      flash[:notice] = message
    else
      flash[:error] = message
    end

    redirect_to facility_account_allocation_path
    puts "[allocation_update][end]"


    return true
=end
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
    puts "[available_account_types]"
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

end
