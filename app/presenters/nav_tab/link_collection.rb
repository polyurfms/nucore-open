# frozen_string_literal: true

class NavTab::LinkCollection

  include Rails.application.routes.url_helpers
  include TranslationHelper

  attr_reader :ability, :facility, :user, :curr_user

  delegate :single_facility?, to: :facility

  def initialize(facility, ability, user, acting_id = 0)
    @facility = facility || Facility.cross_facility
    @ability = ability
    @user = user
    @acting_id = acting_id
    find_curr_user(@acting_id) unless @acting_id == 0
  end

  def self.tab_methods
    @tab_methods ||= %i(
      admin_orders
      admin_reservations
      admin_billing
      admin_products
      admin_users
      admin_reports
      admin_facility
    )
  end

  def find_curr_user(acting_id)
    @curr_user = User.find(@acting_id)
  end

  def admin
    admin_only
  end

  def customer
    # [orders, reservations, payment_sources, user_delegations]
    # count = User.check_academic_user_and_payment_source(@user.id).count
    menu_array = [payment_sources, reservations, orders, user_profile]
    # if(count > 0)
    #   menu_array.push(user_delegations)
    # end
    return menu_array
  end

  def delegate_tab
    menu_array = [payment_sources, reservations, orders]
    if @user.administrator?
        menu_array.push(user_delegations)
      end
    return menu_array
    # [orders, reservations, payment_sources]
  end

  def home_button
    SettingsHelper.feature_on?(:use_manage)
    if SettingsHelper.feature_on?(:use_manage)
      use
    else
      home
    end
  end

  private

  def user_profile
    NavTab::Link.new(tab: :user_profile, text: I18n.t("pages.user_profile"), url: edit_current_profile_path)
  end

  def payment_sources
    is_show = false
    unless @acting_id == 0 
      # @curr_user = User.find(@acting_id)
      is_show = @curr_user.payment_source_owner?
    else 
      is_show = @user.payment_source_owner?
    end
    
    if is_show
      NavTab::Link.new(
        tab: :payment_sources,
        # text: t_my(Account),
        text: I18n.t("pages.my_payment_sources"),
        subnav: [accounts, transactions, transactions_in_review],
      )
    else
      NavTab::Link.new(
        tab: :payment_sources,
        # text: t_my(Account),
        text: I18n.t("pages.my_payment_sources"),
        url: accounts_path,
      )

    end
  end

  def accounts
    # NavTab::Link.new(tab: :accounts, text: t_my(Account), url: accounts_path)
    NavTab::Link.new(tab: :accounts, text: I18n.t("pages.my_payment_sources"), url: accounts_path)
  end

  def transactions
    NavTab::Link.new(tab: :transactions, text: I18n.t("pages.transactions"), url: transactions_path)
  end

  def transactions_in_review
    count = 0
    # @curr_user = User.find(@acting_id) unless @acting_id == 0
    unless @acting_id == 0
        # @curr_user = User.find(@acting_id)
        count = user.administered_order_details(@curr_user).in_review.count
      else 
        count = user.administered_order_details(@user).in_review.count
    end
    # count = user.administered_order_details.in_review.count
    NavTab::Link.new(tab: :transactions_in_review, text: I18n.t("pages.transactions_in_review", count: count), url: in_review_transactions_path)
  
    # count = user.administered_order_details.in_review.count
    # NavTab::Link.new(tab: :transactions_in_review, text: I18n.t("pages.transactions_in_review", count: count), url: in_review_transactions_path)
  end

  def files
    NavTab::Link.new(tab: :my_files, text: I18n.t("views.my_files.index.header"), url: my_files_path) if SettingsHelper.feature_on?(:my_files)
  end

  def user_delegations
    NavTab::Link.new(tab: :user_delegations, text: I18n.t("pages.user_delegations"), url: user_delegations_path)
  end

  def admin_billing
    if single_facility? && ability.can?(:manage_billing, facility)
      NavTab::Link.new(tab: :admin_billing, url: billing_tab_landing_path)
    end
  end

  def admin_only
    self.class.tab_methods.map do |tab_method|
      send(tab_method)
    end.select(&:present?)
  end

  def admin_orders
    if single_facility? && ability.can?(:administer, Order)
      NavTab::Link.new(tab: :admin_orders, url: facility_orders_path(facility))
    end
  end

  def admin_products
    if single_facility? && ability.can?(:administer, Product)
      NavTab::Link.new(tab: :admin_products, url: facility_products_path(facility))
    end
  end

  cattr_accessor(:report_tab_subnav) { [:general_reports, :instrument_utilization_reports] }

  def admin_reports
    if single_facility? && ability.can?(:manage, Reports::ReportsController)
      NavTab::Link.new(
        tab: :admin_reports,
        subnav: report_tab_subnav.map { |method_name| send(method_name) },
      )
    end
  end

  def admin_reservations
    if single_facility? && ability.can?(:administer, Reservation)
      NavTab::Link.new(
        tab: :admin_reservations,
        url: timeline_facility_reservations_path(facility),
      )
    end
  end

  def admin_users
    if single_facility? && ability.can?(:administer, User)
      NavTab::Link.new(tab: :admin_users, url: facility_users_path(facility))
    end
  end

  def admin_facility
    if single_facility? && ability.can?(:edit, facility)
      NavTab::Link.new(tab: :admin_facility, url: manage_facility_path(facility))
    end
  end

  def billing_tab_landing_path
    facility_transactions_path(facility)
  end

  def general_reports
    NavTab::Link.new(
      text: I18n.t("pages.general_reports"),
      url: facility_general_reports_path(facility, report_by: :product),
    )
  end

  def use
    url = facility ? facility_path(facility) : root_path
    NavTab::Link.new(tab: :use, url: url)
  end

  def manage
    NavTab::Link.new(text: I18n.t("pages.manage", model: Facility.model_name.human(count: 2)), url: list_facilities_url)
  end

  def instrument_utilization_reports
    NavTab::Link.new(
      text: I18n.t("pages.instrument_utilization_reports"),
      url: facility_instrument_reports_path(facility, report_by: :instrument),
    )
  end

  def orders
    # NavTab::Link.new(tab: :orders, text: t_my(Order), url: orders_path)
    NavTab::Link.new(tab: :orders, text: I18n.t("pages.my_items"), url: orders_path)
  end

  def reservations
    NavTab::Link.new(
      tab: :reservations,
      # text: t_my(Reservation),
      text: I18n.t("pages.my_reservation"),
      url: reservations_path,
    )
  end

  def home
    NavTab::Link.new(tab: :home, url: root_path)
  end

end
