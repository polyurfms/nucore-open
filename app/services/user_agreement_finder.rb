# frozen_string_literal: true

class UserAgreementFinder
    def initialize(user, facility_url_name=nil, product_url_name=nil)
        @user = user
        @facility = Facility.find_by(url_name: facility_url_name) if(!facility_url_name.nil?)
        @product_url_name = product_url_name if(!product_url_name.nil?)
    end  
     
    def check_agreement()
        is_agreed = true
        @user_agreement = UserAgreement.where(facility_id: @facility, user_id: @user)
    
        if @user_agreement.count < 1
            is_agreed = false 
        end
        return is_agreed
    end

end


