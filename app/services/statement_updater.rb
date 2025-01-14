# frozen_string_literal: true

class StatementUpdater

  attr_accessor :statement_id, :errors, :session_user, :facility_id

  def initialize(params)
    @statement_id = params[:statement_id]
    @facility_id = params[:facility_id]
  end

  def rollback_statement
    @has_error = false
    OrderDetail.transaction do
      @has_error = remove_order_detail_from_statement
      raise ActiveRecord::Rollback if @has_error
    end

    ! @has_error
  end

  def formatted_errors
    errors.join("<br/>").html_safe
  end

  private

  def remove_order_detail_from_statement
    statement = Statement.find_by_id(@statement_id)
    order_details = OrderDetail.where(statement_id: @statement_id)

    order_details.each do |od|
      if od.reconciled?
        return true
      else
        statement.remove_order_detail(od)
      end
    end

    return false
  end

end
