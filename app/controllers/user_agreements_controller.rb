
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
        phone = agreement_params
        
        @user = User.find(session_user.id)
        @user.update(phone: phone)
        
        if UserAgreement.where(user_id:session_user).count == 0
            userAgreement = UserAgreement.create(user_id:session_user.id,accept:true ,created_at:Time.zone.now , updated_at:Time.zone.now )
        else
            userAgreement = UserAgreement.find_by(user_id:session_user)
            userAgreement.accept = true
            userAgreement.save
        end


        session[:user_agreement_record] = 1
        session[:accept] = true
                    

        render json: true
    end
  
    
    def agreement_params
        return params.permit(:phone)["phone"]
    end
  end
  