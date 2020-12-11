# frozen_string_literal: true

module ExternalAccounts

  class PaymentSourceRequestsController < ApplicationController
    
    customer_tab :all
    before_action :authenticate_user!
    before_action :check_acting_as

    before_action { @active_tab = "payment_source_requests" }

    def index

      @result = PaymentSourceRequestSearch.where(user_id: session_user.id) 
      
      puts JSON.parse(@result.to_json)

      @cutoff = Time.zone.now - Settings.send_payment_source_requests

      # @user  = User.find(session_user[:id])
      # str = " SELECT accounts.id, accounts.account_number, accounts.description, accounts.expires_at, payment_source_requests.created_at, "
      # str += " CASE WHEN payment_source_requests.created_at >= '#{cutoff.strftime("%Y-%m-%d %H:%M:%S")}' THEN 0 ELSE 1 END AS is_overtime "
      # str += " FROM accounts "
      # str += " INNER JOIN external_accounts ON accounts.account_number = external_accounts.account_number "
      # str += " LEFT JOIN payment_source_requests ON payment_source_requests.account_id = accounts.id AND payment_source_requests.user_id = #{session_user.id} "
      # str += " WHERE external_accounts.username = '#{session_user.username}' AND external_accounts.user_role = 'N' AND external_accounts.account_number NOT IN ( "
      # str += " SELECT a.account_number FROM account_users au "
      # str += " INNER JOIN accounts a ON au.account_id = a.id "
      # str += " INNER JOIN users u ON u.id = au.user_id "
      # str += " WHERE au.user_role = 'Purchaser' AND u.id = #{session_user.id} AND au.deleted_at IS NULL) "

      # @exec_uery = ActiveRecord::Base.connection.exec_query(str)
      # @result = @exec_uery
    end

    def show
    end

    def sendMail
      account = Account.find(params[:id])
      user = User.find(account.account_users.find_by(account_id: account.id, user_role: "Owner").user_id)


      request_user = User.find(session_user[:id])
      
      unless(account.nil? && user.nil? && request_user.nil?)
        @payment_sorce_request_email = PaymentSourceRequest.find_by(account_id: account.id, user_id: session_user[:id])

        if (@payment_sorce_request_email.nil?)
          @payment_sorce_request_email = PaymentSourceRequest.new
          @payment_sorce_request_email.account_id = account.id
          @payment_sorce_request_email.user_id = session_user[:id]
          @payment_sorce_request_email.created_by = session_user[:id]
          @payment_sorce_request_email.updated_by = session_user[:id]

          if (@payment_sorce_request_email.save) 
            PaymentSourceRequestMailer.notify(user: user, request_user: request_user, account: account).deliver_later
            flash[:notice] = "Email sent out"
          else
            flash[:notice] = "Error to send email"
          end
        else 
          currDatetime = Time.zone.now
          if (@payment_sorce_request_email.update_attributes(:updated_by => session_user[:id], :created_by => session_user[:id], :created_at => "#{currDatetime.strftime("%Y-%m-%d %H:%M:%S")}", :updated_at => "#{currDatetime.strftime("%Y-%m-%d %H:%M:%S")}"))
            PaymentSourceRequestMailer.notify(user: user, request_user: request_user, account: account).deliver_later
            flash[:notice] = "Email sent out"
          else
            flash[:notice] = "Error to send email"
          end
        end
      else 
        flash[:notice] = "Error to send email"
      end

      redirect_to "/payment_source_requests"
    end


  end  
  
end
