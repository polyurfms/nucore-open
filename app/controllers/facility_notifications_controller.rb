# frozen_string_literal: true

class FacilityNotificationsController < ApplicationController

  include SortableColumnController

  admin_tab     :all
  before_action :authenticate_user!
  before_action :check_acting_as

  before_action :init_current_facility
  before_action :check_billing_access

  before_action :check_review_period

  layout "two_column_head"

  def initialize
    @active_tab = "admin_billing"
    super
  end

  def check_review_period
    raise ActionController::RoutingError.new("Notifications disabled with a zero-day review period") unless SettingsHelper.has_review_period?
  end

  # GET /facilities/notifications
  def index
    order_details = OrderDetail.need_notification.for_facility(current_facility)
    @payment_type_filter = true

    @search_form = TransactionSearch::SearchForm.new(params[:search])
    @search = TransactionSearch::Searcher.billing_search(order_details, @search_form, include_facilities: current_facility.cross_facility?)
    @date_range_field = @search_form.date_params[:field]
    if params[:sort].nil?
      # @order_details = @search.order_details
      @order_details = @search.order_details.paginate(page: params[:page], per_page: 200)
    else
      # @order_details = @search.order_details.reorder(sort_clause)
      @order_details = @search.order_details.reorder(sort_clause).paginate(page: params[:page], per_page: 200)
    end


    @order_detail_action = :send_notifications
  end

  # POST /facilities/notifications/send
  def send_notifications
    if params[:order_detail_ids].nil? || params[:order_detail_ids].empty?
      flash[:error] = I18n.t "controllers.facility_notifications.no_selection"
      redirect_to action: :index
      return
    end

    sender = NotificationSender.new(current_facility, params, true)

    if sender.perform
      flash[:notice] = send_notification_success_message(sender)
      sender.order_details.each do |order_detail|
        LogEvent.log(order_detail, :notify, current_user)
      end
    else
      flash[:error] = I18n.t("controllers.facility_notifications.errors_html", errors: sender.errors.join("<br/>")).html_safe
    end
    @accounts_to_notify = sender.account_ids_to_notify
    @errors = sender.errors

    redirect_to action: :index
  end

  # GET /facilities/notifications/in_review
  def in_review
    order_details = OrderDetail.in_review.for_facility(current_facility)

    @payment_type_filter = true

    @search_form = TransactionSearch::SearchForm.new(params[:search])

    @search_form.date_range_start = @search_form.date_range_start unless @search_form.date_range_start.nil?
    @search_form.date_range_end = @search_form.date_range_end unless @search_form.date_range_end.nil?

    @search = TransactionSearch::Searcher.billing_search(order_details, @search_form, include_facilities: current_facility.cross_facility?)
    @date_range_field = @search_form.date_params[:field]

    if params[:sort].nil?
      @order_details = @search.order_details.reorder(:reviewed_at)
    else
      @order_details = @search.order_details.reorder(sort_clause)
    end

    @order_detail_action = :mark_as_reviewed
    @extra_date_column = :reviewed_at
  end

  # GET /facilities/notifications/in_review/mark
  def mark_as_reviewed
    if params[:order_detail_ids].nil? || params[:order_detail_ids].empty?
      flash[:error] = I18n.t "controllers.facility_notifications.no_selection"
    else
      @errors = []
      @order_details_updated = []
      params[:order_detail_ids].each do |order_detail_id|
        begin
          od = OrderDetail.for_facility(current_facility).readonly(false).find(order_detail_id)
          od.reviewed_at = Time.zone.now
          od.save!
          LogEvent.log(od, :review, current_user)
          @order_details_updated << od
        rescue => e
          logger.error(e.message)
          @errors << order_detail_id
        end
      end
      flash[:notice] = I18n.t("controllers.facility_notifications.mark_as_reviewed.success") if @order_details_updated.any?
      flash[:error] = I18n.t("controllers.facility_notifications.mark_as_reviewed.errors", errors: @errors.join(", ")) if @errors.any?
    end
    redirect_to action: :in_review
  end

  private

  def send_notification_success_message(sender)
    if sender.accounts_notified_size == 0
      "Orders notification email skipped"
    elsif sender.accounts_notified_size > 10
      I18n.t("controllers.facility_notifications.send_notifications.success_count", accounts: sender.accounts_notified_size)
    else
      I18n.t("controllers.facility_notifications.send_notifications.success_html", accounts: sender.accounts_notified.map(&:account_list_item).join("<br/>")).html_safe
    end
  end

  def sort_lookup_hash
    {
      "order_number" => "order_details.order_id",
      "fulfilled_date" => "order_details.fulfilled_at",
      "product_name" => "products.name",
      "ordered_for" => ["#{User.table_name}.last_name", "#{User.table_name}.first_name"],
      "payment_source" => "accounts.description",
      "actual_subsidy" => "order_details.actual_cost",
      # "actual_subsidy" => "order_details.actual_subsidy",
      "state" => "order_details.state",
    }
  end

end
