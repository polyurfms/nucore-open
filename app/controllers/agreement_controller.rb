
class AgreementController <  ApplicationController

  before_action :authenticate_user!

  # GET /agreement
  def index
    if have_global_agreement?
      redirect_to '/facilities'
    else
      @is_admin = session_user.administrator? ? true : false
    end
  end

  def show
    if session[:facility_url_name].nil? || session[:product_url_name].nil?
      raise ActiveRecord::RecordNotFound
    else

      check_supervisor()
      
      @product = Product.find_by(url_name:session[:product_url_name])
      @facility = Facility.find_by(id: @product.facility_id)
      is_agree = UserAgreementFinder.new(session[:acting_user_id] || session_user.id, session[:facility_url_name], session[:product_url_name]).check_agreement
      if is_agree
        if !session[:facility_agreement_list].include?(@facility.id)
          session[:facility_agreement_list].push(@facility.id)
        end
        case @product.type
        when "Item"
          redirect_to facility_item_path(@facility , @product)
        when "Service"
          redirect_to facility_service_path(@facility , @product)
        when "Instrument"
          redirect_to facility_instrument_path(@facility , @product)
          # redirect_to new_facility_instrument_single_reservation_path(@facility , @product)
        when "Bundle"
          redirect_to facility_bundle_path(@facility , @product)
        else
          raise ActiveRecord::RecordNotFound
        end

        session[:facility_url_name] = nil
        session[:product_url_name] = nil
      else
        @template = AgreementTemplate.find_by(facility_id: @facility.id)
      end
    end
   end

  def agree
    facility_id = agreement_params

    if facility_id.nil?
      flash[:error] = text("Error")
      redirect_to "/"
    else
      @facility = Facility.find_by(id: facility_id)

      if session[:facility_agreement_list].include?(@facility.id)
        redirect_to facility_path(@facility)
      else 
        @product = Product.find_by(url_name: session[:product_url_name])
        # user = User.find(session_user[:id])

        @agreement = UserAgreement.new()
        @agreement.user_id = session[:acting_user_id] || session_user.id
        @agreement.accept = true
        @agreement.facility_id = @facility.id

        if @agreement.save
          session[:facility_agreement_list].push(@facility.id)
          session[:facility_url_name] = nil
          session[:product_url_name] = nil
          case @product.type
          when "Item"
            redirect_to facility_item_path(@facility , @product)
          when "Service"
            redirect_to facility_service_path(@facility , @product)
          when "Instrument"
            redirect_to facility_instrument_path(@facility , @product)
            # redirect_to new_facility_instrument_single_reservation_path(@facility , @product)
          when "Bundle"
            redirect_to facility_bundle_path(@facility , @product)
          else
            raise ActiveRecord::RecordNotFound
          end
        else
          flash[:error] = text("Error")
          redirect_to "/"
        end
      end
    end
  end

  def agreement_params
    return params.permit(:facility)["facility"]
  end

  def have_global_agreement?
    puts "check_global_agreement starts"
    is_agreed = true
    @user_agreement = UserAgreement.where(facility_id: nil, user_id: session[:acting_user_id] || session_user.id)

    if @user_agreement.count < 1
        is_agreed = false
    end
    return is_agreed

  end

  private
  def check_supervisor
    if !session_user.blank? && !request.env['PATH_INFO'].eql?('/users/sign_out') && !request.env['PATH_INFO'].eql?('/users/sign_in') && session_user.is_normal_user?
      session[:had_supervisor] = session_user.has_supervisor? ? 1 : 0

      if session[:had_supervisor] == 0
        #Check role
        if (session_user.is_academic == true)
          session_user.create_default_supervisor!                
          session[:had_supervisor] = 1
          redirect_to '/facilities'
        else
          return redirect_to '/no_supervisor' unless request.env['PATH_INFO'].eql?('/no_supervisor')
        end
      end
    end
  end

 end
