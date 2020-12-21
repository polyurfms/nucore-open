class FundingRequestsController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_account

  helper_method :get_amt, :get_type , :get_status , :get_total_amount, :is_allow_request


  def initialize
    @active_tab = "accounts"
    #i18n_patch = ".account_transactions.index."
    #operation_type = "operation_type."
    #status = "status."
    #@lock_fund_string = I18n.t(i18n_patch+operation_type+"lock_fund")
    #@lock_fund_code = I18n.t(i18n_patch+operation_type+"lock_fund_code")
    #@unlock_fund_string = I18n.t(i18n_patch+operation_type+"unlock_fund")
    #@unlock_fund_code = I18n.t(i18n_patch+operation_type+"unlock_fund_code")

    #@prcoeesing_code = I18n.t(i18n_patch+status+"processing_code")
    #@processing_string = I18n.t(i18n_patch+status+"processing_string")
    #@success_code = I18n.t(i18n_patch+status+"success_code")
    #@success_string = I18n.t(i18n_patch+status+"success_string")
    #@failded_code = I18n.t(i18n_patch+status+"failded_code")
    #@failded_string = I18n.t(i18n_patch+status+"failded_string")
    super
  end

  #/accounts/1/account_transactions
  def index

  end

  def edit
  end

  def show
      action = "show"
      @active_tab = "accounts"
  end

  def ability_resource
    @account
  end

  def init_account
    if params.key? :id
      puts "[id]" + params[:id].to_s
      @account = Account.find params[:id].to_i
    elsif params.key? :account_id
      puts "[account_id]" + params[:account_id].to_s
      @account = Account.find params[:account_id].to_i
    end

    @funding_request = FundingRequest.new
    @funding_request.request_type="LOCK_FUND_REQUEST"

  end

  def is_allow_request
    #account_transactions = AccountTransaction.find_by(account_id:@account)

    allow_request = true

    @account.funding_requests.each  do |at|

      if at.status == "PROCESSING"
        allow_request = false
      end

    end

    return allow_request
  end


  def funding_request_params
      params.require(:funding_request).permit(:request_type, :credit_amt, :debit_amt, :account_id, :request_amount)
  end

  def create_funding_request
    puts "[create_funding_request()][START]"

    #message = "Error : Allocation must be a positive number!"
    fr_param = params[:funding_request]
    account_id = fr_param[:account_id].to_i

    @account = session_user.accounts.find(account_id)

   # puts "[create_account_transactions()][@account.id]" + @account.to_s
   #  operation_type = account_transaction[:operation_type].to_s
   # puts "[create_account_transactions()][operation_type]" + operation_type
   #  amt = account_transaction[:amt].to_f
   # puts "[create_account_transactions()][amt]" + amt.to_s


    if is_allow_request

      @funding_request = FundingRequest.new(
              funding_request_params.merge(
                created_by: session_user.id,
                status: "PROCESSING"
              ),
            )


      if @funding_request.save
        flash[:notice] = "Save success" #text("update.success")
        redirect_to account_funding_requests_path(account_id)
      else
        #@input_amt = amt
        flash.now[:error]= @funding_request.errors.first[1]
        puts @funding_request.request_type
        render :index
      end

    else
      flash[:error] = I18n.t(".funding_requests.index.message.in_progress")
      redirect_to account_funding_requests_path(account_id)
    end

  end

end
