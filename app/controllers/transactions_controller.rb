# frozen_string_literal: true

class TransactionsController < ApplicationController

  include SortableColumnController

  customer_tab :all
  before_action :authenticate_user!
  before_action :check_acting_as
  include OrderDetailsCsvExport

  def initialize
    @active_tab = "accounts"
    super
  end

  def index

    # order_details = current_user.administered_order_details.joins(:order)
     order_details = @acting_user.administered_order_details.joins(:order)
    @export_enabled = true

    @search_form = TransactionSearch::SearchForm.new(
      params[:search],
      defaults: {
        date_range_start: format_usa_date(1.month.ago.beginning_of_month),
      },
    )

    @search = TransactionSearch::Searcher.new(TransactionSearch::FacilitySearcher,
                                              TransactionSearch::AccountSearcher,
                                              TransactionSearch::ProductSearcher,
                                              TransactionSearch::DateRangeSearcher,
                                              TransactionSearch::OrderStatusSearcher,
                                              TransactionSearch::AccountOwnerSearcher,
                                              TransactionSearch::OrderedForSearcher).search(order_details, @search_form)
    @date_range_field = @search_form.date_params[:field]

    if params[:sort].nil?
      @order_details = @search.order_details
    else
      @order_details = @search.order_details.reorder(sort_clause)
    end

    respond_to do |format|
      format.html { @order_details = @order_details.paginate(page: params[:page]) }
      format.csv { handle_csv_search }
    end
  end

  def in_review
    @recently_reviewed = @acting_user.administered_order_details.recently_reviewed.paginate(page: params[:page])
    order_details = @acting_user.administered_order_details.in_review

    # @recently_reviewed = current_user.administered_order_details.recently_reviewed.paginate(page: params[:page])
    # order_details = current_user.administered_order_details.in_review

    @search_form = TransactionSearch::SearchForm.new(params[:search])
    @search = TransactionSearch::Searcher.new(TransactionSearch::FacilitySearcher,
                                              TransactionSearch::AccountSearcher,
                                              TransactionSearch::ProductSearcher,
                                              TransactionSearch::DateRangeSearcher,
                                              TransactionSearch::OrderStatusSearcher,
                                              TransactionSearch::AccountOwnerSearcher,
                                              TransactionSearch::OrderedForSearcher).search(order_details, @search_form)
    @date_range_field = @search_form.date_params[:field]
    @order_details = @search.order_details.reorder(sort_clause)

    @extra_date_column = :reviewed_at
    @order_detail_action = :mark_as_reviewed
    @order_detail_link = {
      text: text("shared.dispute"),
      display?: proc { |order_detail| order_detail.can_dispute? },
      proc: proc { |order_detail| order_order_detail_path(order_detail.order, order_detail) },
    }
  end

  def mark_as_reviewed
    if params[:order_detail_ids].nil? || params[:order_detail_ids].empty?
      flash[:error] = I18n.t "controllers.facility_notifications.no_selection"
    else
      @errors = []
      @order_details_updated = []
      params[:order_detail_ids].each do |order_detail_id|
        begin
          od = OrderDetail.readonly(false).find(order_detail_id)
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
