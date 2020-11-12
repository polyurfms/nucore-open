
class UserAgreementsController < ApplicationController


    include AZHelper
    include OrderDetailsCsvExport
  
  
    def get_is_agree_terms
        if UserAgreement.where(user_id:session_user).count == 0
             render json: false
        else
            render json: UserAgreement.find_by(user_id:session_user).accept
        end
       
    
    end

    # GET /agree_terms
    def agree
        puts "[UserAgreementController][agree]"
        if UserAgreement.where(user_id:session_user).count == 0
            puts "[UserAgreementController][agree][create]"
             userAgreement = UserAgreement.create(user_id:session_user.id,accept:true ,created_at:Time.zone.now , updated_at:Time.zone.now )
        else
            puts "[UserAgreementController][agree][update]"
            userAgreement = UserAgreement.find_by(user_id:session_user)
            userAgreement.accept = true
            userAgreement.save
        end

        render json: true
    end
  
  end
  