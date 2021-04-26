# frozen_string_literal: true

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  include DateHelper

  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Make the following methods available to all views
  helper_method :cross_facility?
  helper_method :current_facility, :session_user, :manageable_facilities, :operable_facilities, :acting_user, :acting_as?, :check_acting_as, :current_cart, :backend?, :has_delegated?
  helper_method :open_or_facility_path

  before_action :set_paper_trail_whodunnit,:check_supervisor, :check_agreement
  before_action :check_delegations

  before_action :get_facility_agreement_list

  # Navigation tabs configuration
  attr_accessor :active_tab
  include NavTab

  # return whatever facility is indicated by the :facility_id or :id url parameter
  # UNLESS that url parameter has the value of 'all'
  # in which case, return the all facility

  def get_facility_agreement_list
    if (!session_user.nil? && session[:facility_agreement_list].nil?)
      session_user.get_is_normal_user?     
      facility_agreement_list = []
      facility_agreement_list.push(0)
      @user = session[:acting_user_id] || session_user.id
      @user_agreement = UserAgreement.where(user_id: @user)

      @user_agreement.each do |u|
        if (!u.facility_id.nil?)
          facility_agreement_list.push(u.facility_id)
        end
      end
      session[:facility_agreement_list] = facility_agreement_list
    end
  end

  def has_delegated
    if(!session[:acting_user_id].nil? && !session[:acting_user_id].blank?)
      # @user  = User.find_by(username: session_user[:username])
      @user  = User.find(session_user[:id])
      unless @user.nil? && @user.username.blank?
        @delegate_list = User.joins("LEFT JOIN user_delegations ON user_delegations.delegator = users.id WHERE user_delegations.delegatee LIKE '#{@user.username}' and user_delegations.delegator = #{session[:acting_user_id]}")
        if @delegate_list.size() > 0
          return true
        end
      end

      return true if session_user.administrator?

    end
    return false
  end

  def check_delegations
    # Avoid fake delegations

    unless session[:had_supervisor] == 0
      if(!session[:is_selected_user] == true && !session[:acting_user_id].nil? && !session[:acting_user_id].eql?(""))
        redirect_to "/" if !has_delegated
      end

      # Detect is first login action and redirect to account selection
      # if(!request.env['PATH_INFO'].eql?('/agreement') && !request.env['PATH_INFO'].include?('/user_delegations/') && !request.env['PATH_INFO'].eql?('/users/sign_in') && !request.env['PATH_INFO'].eql?('/users/sign_out') && session[:is_selected_user].nil?)
      if (!session_user.nil? && !request.env['PATH_INFO'].eql?('/agree_terms') && !request.env['PATH_INFO'].eql?('/agreement') && !request.env['PATH_INFO'].include?('/user_delegations/') && !request.env['PATH_INFO'].eql?('/users/sign_in') && !request.env['PATH_INFO'].eql?('/users/sign_out') )
        unless session[:is_selected_user] == true
          redirect_to '/user_delegations/switch'
        end
      end
    end
  end

#  def after_sign_in_path_for(resource)
#    puts "after_sign_in_path_for 1"
#    '/orders/pending'
#  end

  def check_supervisor

    if !session_user.blank? && !request.env['PATH_INFO'].eql?('/users/sign_out') && !request.env['PATH_INFO'].eql?('/users/sign_in') && !session_user.administrator?
      session[:had_supervisor] = session_user.supervisor.blank? ? 0 : 1

      if session[:had_supervisor] == 0
        #Check role
        if (session_user.is_academic == true)
          @user = User.find(session_user[:id])
          @user.update_attributes(supervisor: @user.username)
          session[:had_supervisor] = 1
          redirect_to '/facilities'
        else
          redirect_to '/no_supervisor' unless request.env['PATH_INFO'].eql?('/no_supervisor')
        end
      end
    end
  end

  def check_agreement

    if (!session_user.nil? )

      #skip welcome page if admin
      unless session_user.administrator?
        unless session[:had_supervisor] == 0
          #only user login can visit agreement
          if  request.env['PATH_INFO'].eql?('/agreement') && session_user.blank?
            redirect_to '/facilities'
          end

          # when user login and page is not agreement or agreement api
          if !session_user.blank? &&
             !request.env['PATH_INFO'].eql?('/agreement') &&
             !request.env['PATH_INFO'].eql?('/agree_terms') &&
             !request.env['PATH_INFO'].eql?('/users/sign_out')

            # get rocord from db when frist time store data in session
            if session[:user_agreement_record] == nil
              #puts "[check_agreement][get record][user_agreement_record]"
              # session[:user_agreement_record] = UserAgreement.where(user_id:session_user).count
              session[:user_agreement_record] = UserAgreement.where(user_id:session_user, facility_id: nil).count
            end

            # get rocord from db when frist time store data in session
            if session[:user_agreement_record] > 0
              if session[:accept] == nil
                #puts "[check_agreement][get record][accept]"
                session[:accept] = UserAgreement.where(user_id:session_user).first.accept
              end
            end

            #puts "[check_agreement]session[:accept]" + (session[:accept] ? "true" : "false")
            #puts "[check_agreement]session[:user_agreement_record]" +session[:user_agreement_record].to_s

            if session[:accept] == 0
              redirect_to '/agreement'
            else
              if !session[:accept]
                redirect_to '/agreement'
              end
            end

          end
        end
      end
    end
  end

    # after login redirect user to agreement page
=begin
      def after_sign_in_path_for(resource)
          puts "***********************"
        puts "after_sign_in_path_for 2"
        puts "***********************"

        if UserAgreement.where(user_id:session_user).count == 0
          '/agreement'
        else
          if UserAgreement.where(user_id:session_user).first.accept
            # '/facilities'
            '/user_delegations/switch'
          else
            '/agreement'
          end
        end
      end
=end

  def current_facility
    is_agree = true

    facility_id = params[:facility_id] || params[:id]
    @facility = Facility.find_by(url_name: facility_id)
    if(!params[:facility_id].nil? && !params[:id].nil? && !session[:facility_agreement_list].nil?)
      if (session_user.is_normal_user)
        is_agree = session[:facility_agreement_list].include?(@facility.id)
      end
    end

    if(is_agree)
      @current_facility ||=
        case
        when facility_id.blank?
          nil # TODO: consider a refactoring to use a null object
        when facility_id == Facility.cross_facility.url_name
          Facility.cross_facility
        else
          Facility.find_by(url_name: facility_id)
        end
    else
      session[:facility_url_name] = params[:facility_id]
      session[:product_url_name] = params[:id]
      redirect_to agreement_path(@facility.id)
    end

  end

  def cross_facility? # TODO: try to use current_facility.cross_facility? but note current_facility may be nil
    current_facility == Facility.cross_facility
  end

  def init_current_facility
    raise ActiveRecord::RecordNotFound unless current_facility
  end

  # TODO: refactor existing calls of this definition to use this helper
  def current_cart
    acting_user.cart(session_user)
  end

  def init_current_account
    @account = Account.find(params[:account_id] || params[:id])
  end

  def check_acting_as
    raise NUCore::NotPermittedWhileActingAs if acting_as? && !has_delegated
  end

  def backend?
    params[:controller].starts_with?("facilit")
  end

  # authorization before_filter for billing actions
  def check_billing_access
    # something has gone wrong,
    # this before_filter shouldn't be run
    raise ActiveRecord::RecordNotFound unless current_facility

    authorize! :manage_billing, current_facility
  end

  # helper for actions in the 'Billing' manager tab
  #
  # Purpose:
  #   used to get facilities normally used to scope down
  #   which order_details / journals are shown within the tables
  #
  # Returns
  #   returns an ActiveRecord::Relation of facilities
  #   which order_details / journals should be limited to
  #   when running a transaction search or working in the billing tab
  #
  # depends heavily on value of current_facility
  def manageable_facilities
    @manageable_facilities =
      case
      when current_facility.blank?
        session_user.manageable_facilities
      when current_facility.cross_facility?
        Facility.alphabetized
      else
        Facility.where(id: current_facility.id)
      end
  end

  # return an ActiveRecord:Relation of facilities where this user has a role (ie is staff or higher)
  # Administrator and Global Billing Administrator get a relation of all facilities
  def operable_facilities
    @operable_facilities ||= (session_user.blank? ? [] : session_user.operable_facilities)
  end

  # BCSEC legacy method. Kept to give us ability to override devises #current_user.
  def session_user
    @session_user ||= current_user
  rescue
    nil
  end

  def acting_user
    @acting_user ||= User.find_by(id: session[:acting_user_id]) || session_user
  end

  def has_delegated?
    return has_delegated
  end

  def acting_as?
    return false if session_user.nil?
    acting_user.object_id != session_user.object_id
  end

  # Global exception handlers
  rescue_from ActiveRecord::RecordNotFound do |exception|
    Rails.logger.debug("#{exception.message}: #{exception.backtrace.join("\n")}") unless Rails.env.production?
    render_404(exception)
  end

  rescue_from ActionController::RoutingError do |exception|
    Rails.logger.debug("#{exception.message}: #{exception.backtrace.join("\n")}") unless Rails.env.production?
    render_404(exception)
  end

  def render_404(_exception)
    # Add html fallback in case the 404 is a PDF or XML so the view can be found
    render "/404", status: 404, layout: "application", formats: formats_with_html_fallback
  end

  rescue_from NUCore::PermissionDenied, CanCan::AccessDenied, with: :render_403
  def render_403(_exception)
    # if current_user is nil, the user should be redirected to login
    if current_user
      render "/403", status: 403, layout: "application", formats: formats_with_html_fallback
    else
      store_location_for(:user, request.fullpath)
      redirect_to new_user_session_path
    end
  end

  rescue_from NUCore::NotPermittedWhileActingAs, with: :render_acting_error
  def render_acting_error
    render "/acting_error", status: 403, layout: "application", formats: formats_with_html_fallback
  end

  def after_sign_out_path_for(_)
    if current_facility.present?
      facility_path(current_facility)
    else
      super
    end
  end

  #
  # Will go to the facility version of the path if you are within a facility,
  # otherwise go to the normal version. Useful for sharing views.
  # E.g.:
  # If you are in a facility, open_or_facility_path('account', @account) will link
  # to facility_account_path(current_facility, @account), while if you are not, it will
  # just go to account_path(@account).
  def open_or_facility_path(path, *options)
    path += "_path"
    if current_facility
      path = "facility_" + path
      send(path, current_facility, *options)
    else
      send(path, *options)
    end
  end

  def store_fullpath_in_session
    store_location_for(:user, request.fullpath) unless current_user
  end

  def current_ability
    if has_delegated
      @current_ability ||= Ability.new(acting_user, ability_resource, self)
    else
      @current_ability ||= Ability.new(current_user, ability_resource, self)
    end

  end

  private

  #
  # The +Ability+ class, which is used by cancan for authorization,
  # determines authorization by user and some resource. That resource
  # is returned by this method. By default it is #current_facility.
  # Override here to easily change the resource.
  def ability_resource
    current_facility
  end

  def empty_params
    ActionController::Parameters.new
  end

  def with_dropped_params(&block)
    QuietStrongParams.with_dropped_params(&block)
  end

  def formats_with_html_fallback
    request.formats.map(&:symbol) + [:html]
  end

end
