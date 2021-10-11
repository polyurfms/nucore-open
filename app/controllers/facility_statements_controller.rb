# frozen_string_literal: true

class FacilityStatementsController < ApplicationController

  include SortableColumnController

  admin_tab     :all
  before_action :authenticate_user!
  before_action :check_acting_as
  before_action { @facility = current_facility }

  load_and_authorize_resource class: Statement

  layout lambda {
    action_name.in?(%w(new)) ? "two_column_head" : "two_column"
  }

  include CsvEmailAction

  def initialize
    @active_tab = "admin_billing"
    super
  end

  # GET /facilities/:facility_id/statements
  def index
    search_params = permitted_search_params.merge(current_facility: current_facility)

    @search_form = StatementSearchForm.new(search_params)

    start_date_str = @search_form.date_range_start
    end_date_str = @search_form.date_range_end
    @search_form.date_range_start = @search_form.date_range_start unless @search_form.date_range_start.nil?
    @search_form.date_range_end = @search_form.date_range_end unless @search_form.date_range_end.nil?

    if params[:sort].nil?
      @statements = @search_form.search.order(created_at: :desc)
    else
      @statements = @search_form.search.reorder(sort_clause)
    end


    @search_form.date_range_start = start_date_str
    @search_form.date_range_end = end_date_str

    respond_to do |format|
      format.html { @statements = @statements.paginate(page: params[:page]) }
      format.csv do
        yield_email_and_respond_for_report do |email|
          StatementSearchResultMailer.search_result(email, search_params.to_h).deliver_later
        end
      end
    end
  end

  def permitted_search_params
    (params[:statement_search_form] || empty_params).permit(:date_range_start, :date_range_end, :status, accounts: [], sent_to: [], facilities: [])
  end

  # GET /facilities/:facility_id/statements/new
  def new
    order_details = OrderDetail.need_statement(@facility)
    @order_detail_action = :create

    defaults = SettingsHelper.feature_on?(:set_statement_search_start_date) ? { date_range_start: format_usa_date(1.month.ago.beginning_of_month) } : {}

    @search_form = TransactionSearch::SearchForm.new(params[:search], defaults: defaults)

    @search_form.date_range_start = @search_form.date_range_start unless @search_form.date_range_start.nil?
    @search_form.date_range_end = @search_form.date_range_end unless @search_form.date_range_end.nil?

    @search = TransactionSearch::Searcher.billing_search(order_details, @search_form, include_facilities: current_facility.cross_facility?)
    @date_range_field = @search_form.date_params[:field]
    @order_details = @search.order_details.reorder(sort_clause)
  end

  # POST /facilities/:facility_id/statements
  def create
    @statement_creator = StatementCreator.new(order_detail_ids: params[:order_detail_ids], session_user: session_user, current_facility: current_facility)

    if @statement_creator.order_detail_ids.blank?
      flash[:error] = text("no_selection")
    elsif @statement_creator.create
      @statement_creator.send_statement_emails
      flash[:notice] = text(success_message, accounts: @statement_creator.formatted_account_list)

    else
      flash[:error] = text("errors_html", errors: @statement_creator.formatted_errors)
    end

    redirect_to action: :new
  end

  # GET /facilities/:facility_id/statements/:id
  def show
    @statement = Statement.find(params[:id])
  end

  def rollback_statement
    @remove_statement = StatementUpdater.new(params)
    if @remove_statement.rollback_statement
      flash[:notice] = "Invoice rolled back success"
    else
      flash[:error] = "Invoice rolled failed"
    end
    redirect_to facility_statements_path
  end

  private

  def success_message
    SettingsHelper.feature_on?(:send_statement_emails) ? "success_with_email_html" : "success_html"
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
