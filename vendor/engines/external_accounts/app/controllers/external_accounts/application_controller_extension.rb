# frozen_string_literal: true

module ExternalAccounts

  module ApplicationControllerExtension extend ActiveSupport::Concern

    included do
      # def after_sign_in_path_for(resource)
      before_action :check_new_payment_source
    end

    def check_new_payment_source
      if !session_user.blank? && session[:load_payment_source] == nil
        session[:load_payment_source] = 1
        accounts = Account.for_user(session_user)

        # check if payment source not yet created

#        externalAccounts = ResearchProjectMember.where(username: session_user.username).where.not(account_number :accounts.pluck(:account_number))

#        externalAccounts = ResearchProjectMember.where(username: session_user.username, user_role: AccountUser::ACCOUNT_OWNER)

#        externalAccounts = ResearchProject.joins(:research_project_members).where.not(account_number :accounts.pluck(:account_number)).where(username: session_user.username, user_role: AccountUser::ACCOUNT_OWNER)

        externalAccounts = ResearchProject.find_by_sql(["select * from research_projects rp
          join research_project_members rm
            on rm.research_project_id = rp.id
            and rm.username = ?
            and rm.is_left_project = 0
            and rm.user_role = 'OWNER'
          where rp.account_number not in (select a.account_number from accounts a)", session_user.username])

        # Create missing account info
        if !externalAccounts.blank?
          externalAccounts.each do |ea|
            @account = Account.new
            @account.type = "NufsAccount"
            @account.account_number = ea.account_number
            @account.description = "PGMS Project Account " + ea.pgms_project_id
            @account.project_title = ea.project_title
            @account.expires_at = ea.expires_at
            @account.created_by = session_user.id
            @account.updated_by =session_user.id
            @account.created_at = Time.now
            @account.updated_at = Time.now

            #skip missing account user validation
            @account.save(validate: false)

            user = User.find(session_user.id)
            account_user = AccountUser.grant(user, AccountUser::ACCOUNT_OWNER, @account, by: session_user)
            puts ea.id
          end
        end

        #update pyament source expire date
=begin
        externalAccounts = IntfResearchProjectMember.where(username: session_user.username).where(account_number: accounts.pluck(:account_number))
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
=end
        #call super method for the follow up task
        #super
      end



    end
  end

end

#end
