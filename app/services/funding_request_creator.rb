class FundingRequestCreator

  attr_reader :account, :params, :error, :funding_request

  def initialize(account, user, params)
    @account = account
    @params = params
    @user = user
  end

  def save

    if @account.type == "ChequeOrOtherAccount"
      @funding_request = FundingRequest.new(
              funding_request_params.merge(
                created_by: @user.id,
                updated_by: @user.id,
                status: "SUCCESS"
              ),
            )
    else
      @funding_request = FundingRequest.new(
              funding_request_params.merge(
                created_by: @user.id,
                updated_by: @user.id,
                status: "PENDING_CHECK_FUND"
              ),
            )
    end

    ActiveRecord::Base.transaction do

      if @funding_request.request_type == "UNLOCK_FUND_REQUEST"
        if @account.free_balance - @funding_request.credit_amt < 0
          @error = "Failed to create funding request. Release amount over free balance"
          raise ActiveRecord::Rollback
        end
      end

      if @funding_request.save

        if @account.type == "ChequeOrOtherAccount"

          if @funding_request.request_type == 'LOCK_FUND_REQUEST'
            @committed_amt = @account.committed_amt + @funding_request.debit_amt
          else
            @committed_amt = @account.committed_amt - @funding_request.credit_amt
          end

          @account.update_attribute(:committed_amt, @committed_amt)
        end

        @success = :default
        LogEvent.log(@funding_request, :create, @user, metadata: {ref_no: @funding_request.id, type: @funding_request.request_type, amount: @funding_request.request_amount})

      else
        #@input_amt = amt
        @error = "Failed to create funding request"
        raise ActiveRecord::Rollback
      end
    end
  end

  def funding_request_params
      @params.require(:funding_request).permit(:request_type, :credit_amt, :debit_amt, :account_id, :request_amount)
  end


end
