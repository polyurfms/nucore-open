# frozen_string_literal: true

class UsersController < ApplicationController

  module Overridable

    # Should be overridden by custom lookups (e.g. LDAP)
    def service_username_lookup(_username)
      nil
    end

  end

  include Overridable
  include TextHelpers::Translation

  customer_tab :password
  admin_tab     :all
  before_action :init_current_facility, except: [:password, :password_reset]
  before_action :authenticate_user!, except: [:password_reset]
  before_action :check_acting_as

  load_and_authorize_resource except: [:create, :password, :password_reset, :edit, :update, :show], id_param: :user_id
  load_and_authorize_resource only: [:edit, :update, :show, :suspend, :unsuspend, :unexpire], id_param: :id

  layout "two_column"

  cattr_accessor(:user_form_class) { UserForm }

  def initialize
    @active_tab = "admin_users"
    super
  end

  # GET /facilities/:facility_id/users
  def index
    @new_user = User.find_by(id: params[:user])
    @users = User.with_recent_orders(current_facility)
                 .order(:last_name, :first_name)
                 .paginate(page: params[:page])
  end

  # POST /facilities/:facility_id/users/search
  def search
    @user = username_lookup(params[:username_lookup])
    render layout: false
  end

  # GET /facilities/:facility_id/users/new
  def new
    redirect_to action: :new_external if SettingsHelper.feature_off?(:lookup_netids)
  end

  # GET /facilities/:facility_id/users/new_external
  def new_external
    @user = User.new(email: params[:email], username: params[:email])
    @user_form = user_form_class.new(@user)
  end

  # POST /facilities/:facility_id/users
  def create
    if params[:user]
      create_external
    elsif params[:username]
      create_internal
    else
      redirect_to new_facility_user_path
    end
  end

  # GET /facilities/:facility_id/users/:user_id/switch_to
  def switch_to
    unless session_user.id == @user.id
      session[:acting_user_id] = @user.id
      session[:acting_ref_url] = facility_users_path
    end
    redirect_to facility_path(current_facility)
  end

  # GET /facilities/:facility_id/users/:user_id/orders
  def orders
    # order details for this facility
    @order_details = @user.order_details
                          .item_and_service_orders
                          .for_facility(current_facility)
                          .purchased
                          .order(ordered_at: :desc)
                          .paginate(page: params[:page])
  end

  # GET /facilities/:facility_id/users/:id
  def show
  end

  # GET /facilities/:facility_id/users/:user_id/access_list
  def access_list
    # Unsupported in cross-facility mode
    raise ActiveRecord::RecordNotFound if current_facility.cross_facility?

    @facility = current_facility
    @products_by_type = Product.for_facility(@facility).requiring_approval_by_type
    @training_requested_product_ids = @user.training_requests.pluck(:product_id)
    @user_approved_at_for_product_id = @user.approval_dates_by_product
    @user_approval_remark_by_product = @user.approval_remark_by_product
  end

  # GET /facilities/:facility_id/users/:user_id/admin_list
  def product_admin_list
    # Unsupported in cross-facility mode
    raise ActiveRecord::RecordNotFound if current_facility.cross_facility?
    @facility = current_facility
    @facility_products = Product.for_facility(@facility)
    @product_admin_by_user = @user.product_admin_by_user

  end

  # POST /facilities/:facility_id/users/:user_id/access_list/approvals
  def access_list_approvals
    # Unsupported in cross-facility mode
    raise ActiveRecord::RecordNotFound if current_facility.cross_facility?

    update_access_list_approvals
    redirect_to facility_user_access_list_path(current_facility, @user)
  end

  # POST /facilities/:facility_id/users/:user_id/product_admin_list/update
  def product_admin_list_update
    # Unsupported in cross-facility mode
    raise ActiveRecord::RecordNotFound if current_facility.cross_facility?
    assign_product_to_admin_user
    redirect_to facility_user_product_admin_list_path(current_facility, @user)
  end


  # GET /facilities/:facility_id/users/:id/edit
  def edit
    @user_form = user_form_class.new(@user)
  end

  # PUT /facilities/:facility_id/users/:id
  def update
    previous_price_groups = @user.price_groups.to_a
    @user_form = user_form_class.new(@user)
    if @user_form.update_attributes(edit_user_params) && @user.update_price_group(price_group_params) && @user.update_supervisor(edit_supervisor_params, session_user.id)
      if previous_price_groups != @user.price_groups.reload.to_a
        new_price_groups = @user.price_groups.to_a - previous_price_groups
        LogEvent.log(@user, :default_price_group_changed, current_user, metadata: { price_group_rate: new_price_groups.first.name })
      end
      flash[:notice] = text("update.success")
      redirect_to facility_user_path(current_facility, @user)
    else
      flash[:error] = text("update.error", message: @user_form.errors.full_messages.to_sentence)
      render action: "edit"
    end
  end

  def unexpire
    @user.update!(expired_at: nil, expired_note: nil)
    redirect_to facility_user_path(current_facility, @user), notice: text("unexpire.success")
  end

  private

  def training_requested_for?(product)
    @training_requested_product_ids.include? product.id
  end
  helper_method :training_requested_for?

  def create_params
    params.require(:user).permit(*user_form_class.permitted_params)
  end

  def edit_user_params
    @user_form.admin_editable? ? params.require(:user).except(:internal).permit(:email, :first_name, :last_name, :username, :phone, :supervisor, :card_number) : empty_params
  end

  def edit_supervisor_params
    params.require(:user).permit(:supervisor_last_name, :supervisor_first_name, :supervisor_email, :supervisor_netid, :supervisor_dept_abbrev, :supervisor_is_acad_staff)
  end

  def price_group_params
    current_user.administrator? ? params.require(:user).slice(:internal).permit! : empty_params
  end

  def create_external
    @user = User.new
    @user_form = user_form_class.new(@user)
    @user_form.assign_attributes(create_params)

    authorize! :create, @user_form.user

    if @user_form.save
      LogEvent.log(@user_form.user, :create, current_user)
      @user_form.user.create_default_price_group!
      save_user_success(@user_form.user)
    else
      render(action: "new_external") && return
    end
  end

  def create_internal
    @user = username_lookup(params[:username])
    authorize! :create, @user
    if @user.nil?
      flash[:error] = text("users.search.netid_not_found")
      redirect_to facility_users_path
    elsif @user.persisted?
      flash[:error] = text("users.search.user_already_exists", username: @user.username)
      redirect_to facility_users_path
    elsif @user.save
      LogEvent.log(@user, :create, current_user)
      @user.create_default_price_group!
      save_user_success(@user)
    else
      flash[:error] = text("create.error", message: @user.errors.full_messages.to_sentence)
      redirect_to facility_users_path
    end
  end

  def update_access_list_approvals
    if update_approvals.grants_changed?
      flash[:notice] = I18n.t "controllers.users.access_list.approval_update.notice",
                              granted: update_approvals.granted, revoked: update_approvals.revoked
      update_approvals.granted_product_users.each do |product_user|
        LogEvent.log(product_user, :create, current_user)
      end
      update_approvals.revoked_product_users.each do |product_user|
        LogEvent.log(product_user, :delete, current_user)
      end
    else
      flash[:notice] = I18n.t "controllers.users.access_list.remark_update.notice"
    end
    if update_approvals.access_groups_changed?
      add_flash(:notice,
                I18n.t("controllers.users.access_list.scheduling_group_update.notice",
                       update_count: update_approvals.access_groups_changed))
    end

    update_remark(approved_products_from_params)
  end

  def assign_product_to_admin_user

    if update_admin_assignemnts.grants_changed?
      flash[:notice] = I18n.t "controllers.users.product_admin_list.assingment_update.notice",
                              granted: update_admin_assignemnts.granted, revoked: update_admin_assignemnts.revoked
      update_admin_assignemnts.granted_product_admins.each do |product_admin|
        LogEvent.log(product_admin, :create, current_user)
      end
      update_admin_assignemnts.revoked_product_admins.each do |product_admin|
        LogEvent.log(product_admin, :delete, current_user, metadata: { user: product_admin.user, facility: product_admin.facility })
      end
    end
  end

  def update_remark(approved_products_from_params)
    if params[:approved_products].present?
      approved_products_from_params = params[:approved_products]
      approved_products_from_params.each do |id|
        product = Product.find(id)
        product_user = product.find_product_user(@user) || return
        return if id.blank?
        remark = params["remark_#{id}"]
        product_user.remark = remark
        product_user.save
      end
    end
  end

  def update_approvals
    @update_approvals ||= ProductApprover.new(
      Product.for_facility(current_facility).requiring_approval,
      @user,
      session_user,
    ).update_approvals(approved_products_from_params, params[:product_access_group])
  end

  def update_admin_assignemnts
    @update_product_assignment ||= ProductAdminAssigner.new().update_assignments( @user,  Product.for_facility(current_facility), approved_products_from_params)
  end

  def approved_products_from_params
    if params[:approved_products].present?
      Product.find(params[:approved_products])
    else
      []
    end
  end

  def username_lookup(username)
    return nil if username.blank?
    username_database_lookup(username.strip) || service_username_lookup(username.strip)
  end

  def username_database_lookup(username)
    User.find_by("LOWER(username) = ?", username.downcase)
  end

  def save_user_success(user)
    flash[:notice] = text("create.success")
    if session_user.manager_of?(current_facility)
      add_role = html("create.add_role", link: facility_facility_user_map_user_path(current_facility, user), inline: true)
      flash[:notice].safe_concat(add_role)
    end
    # Notifier.new_user(user: user, password: user.password).deliver_later
    redirect_to facility_users_path(user: user.id)
  end

  def add_flash(key, message)
    if flash[key].present?
      flash[key] += " #{message}"
    else
      flash[key] = message
    end
  end

end
