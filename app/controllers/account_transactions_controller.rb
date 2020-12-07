class AccountTransactionsController < ApplicationController

  customer_tab  :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action :init_account

  helper_method :get_amt, :get_type , :get_status



  def initialize
    @active_tab = "accounts"
    @lock_fund_string = I18n.t(".account_transactions.index.operation_type.lock_fund")
    @lock_fund_code = I18n.t(".account_transactions.index.operation_type.lock_fund_code")
    @unlock_fund_string = I18n.t(".account_transactions.index.operation_type.unlock_fund")
    @unlock_fund_code = I18n.t(".account_transactions.index.operation_type.unlock_fund_code")
    
    @prcoeesing_code = I18n.t(".account_transactions.index.status.processing_code")
    @processing_string = I18n.t(".account_transactions.index.status.processing_string")
    @success_code = I18n.t(".account_transactions.index.status.success_code")
    @success_string = I18n.t(".account_transactions.index.status.success_string")
    @failded_code = I18n.t(".account_transactions.index.status.failded_code")
    @failded_string = I18n.t(".account_transactions.index.status.failded_string")
    super
  end

  # GET /accounts/:id/statements
  def index
    #@statements = @account.statements.uniq.paginate(page: params[:page])
  end

  # GET /accounts/:account_id/statements/:id
  def show
      action = "show"
      @active_tab = "accounts"    
  end

  def ability_resource
    @account
  end


  def init_account
    # CanCan will make sure that we're authorizing the account

    if params.key? :id
      puts "[id]" + params[:id].to_s
      @account = Account.find params[:id].to_i
    elsif params.key? :account_id
      puts "[account_id]" + params[:account_id].to_s
      @account = Account.find params[:account_id].to_i
    end

  end


  def get_total_amount

  end

  def create_account_transactions
    puts "[create_account_transactions()][START]"
    #--check status any in process? 
    
    #yes print error message

    #no get json value 
      # check amt number

    account_transaction = params[:account_transaction]
    user_id = account_transaction[:user_id].to_i
    puts "[create_account_transactions()][@account.id]" + @account.to_s
    operation_type = account_transaction[:operation_type].to_s
    puts "[create_account_transactions()][operation_type]" + operation_type
    amt = account_transaction[:amt].to_f
    puts "[create_account_transactions()][amt]" + amt.to_s
    
    #--if status =
    # params[:debit_amt] # lock
    # params[:credit_amt] # unlock
   
    insert_account_transactions = AccountTransaction.new;
    insert_account_transactions.account_id = user_id;
    if operation_type.eql? @lock_fund_string
      insert_account_transactions.operation_type = @lock_fund_code
      insert_account_transactions.debit_amt = amt
      insert_account_transactions.credit_amt = 0
    elsif operation_type.eql? @unlock_fund_string
      insert_account_transactions.operation_type = @unlock_fund_code
      insert_account_transactions.credit_amt = amt
      insert_account_transactions.debit_amt = 0
    end
    insert_account_transactions.status = @prcoeesing_code
    insert_account_transactions.created_at = Time.now
    insert_account_transactions.save;

    #update  db

    #refesh page
    puts "[create_account_transactions()][END]"

    redirect_to account_account_transactions_path(user_id)
  end

  def get_amt(account_transaction)
    if account_transaction.operation_type.eql? @lock_fund_code
        return account_transaction.debit_amt 
        
    elsif account_transaction.operation_type.eql? @unlock_fund_code
        return account_transaction.credit_amt
    end
  end

  def get_type(account_transaction)
    if account_transaction.operation_type.eql? @lock_fund_code
      return @lock_fund_string
      
    elsif account_transaction.operation_type.eql? @unlock_fund_code
      return @unlock_fund_string
    end
  end

  def get_status(account_transaction)
    if account_transaction.status.eql? @prcoeesing_code
      return @processing_string
    elsif account_transaction.status.eql? @success_code
      return @success_string
    elsif account_transaction.status.eql? @failded_code
      return @failded_string
    end

  end
end