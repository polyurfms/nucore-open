# frozen_string_literal: true

module ExternalAccounts

  module ApplicationControllerExtension extend ActiveSupport::Concern

    included do
      def after_sign_in_path_for(resource)

#        if !session_user.blank?
#          Rails.logger.info session_user.id
#          account_users = session_user.account_users
#          account_users.each do |f|
#            puts f.to_log_s
#          end
#        else
#          Rails.logger.info "empty session user"
#        end if

        accounts = Account.for_user(session_user)

#        if !accounts.blank?
#          accounts.each do |a|
#            puts a.id
#          end
#        end

        # check if payment source not yet created
        externalAccounts = ExternalAccount.where(username: session_user.username).where.not(account_number: accounts.pluck(:account_number))

        # Create missing account info
        if !externalAccounts.blank?
          externalAccounts.each do |ea|
            account = Account.new
            account.type = "NufsAccount"
            account.account_number = ea.account_number
            account.description = ea.description
            account.expires_at = ea.expires_at
            account.created_by = session_user.id
            account.created_at = Time.now
            account.updated_at = Time.now
            user = User.find(session_user.id)

            account_user = AccountUser.grant(user, AccountUser::ACCOUNT_OWNER, account, by: session_user)
            puts ea.id
          end
        end

        #update pyament source expire date

        externalAccounts = ExternalAccount.where(username: session_user.username).where(account_number: accounts.pluck(:account_number))
        if !externalAccounts.blank?
          externalAccounts.each do |ea|
            accounts.each do |a|
              puts "#{ea.account_number}:#{a.account_number}:#{ea.expires_at}:#{a.expires_at}"
              if a.type=="NufsAccount" and ea.account_number == a.account_number and ea.expires_at != a.expires_at
                Account.find_by(account_number: ea.account_number).update_column(:expires_at, ea.expires_at)
                break
              end
            end

          end
        end

        #call super method for the follow up task
        super
      end



    end


  end

end
