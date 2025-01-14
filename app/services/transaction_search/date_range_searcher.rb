# frozen_string_literal: true

module TransactionSearch

  class DateRangeSearcher < BaseSearcher

    include DateHelper
    FIELDS = %w(ordered_at fulfilled_at journal_or_statement_date reconciled_at).freeze
    PAYMENT_TYPE_FIELDS = %w(all charge cheque).freeze

    attr_reader :date_range_field
    attr_reader :payment_type_field

    def self.options(only: FIELDS)
      FIELDS.map { |field| [I18n.t(field, scope: "admin.transaction_search.date_range_fields"), field] }
            .select { |_label, value| value.in?(only) }
    end

    def self.payment_type_options(only: PAYMENT_TYPE_FIELDS)
      PAYMENT_TYPE_FIELDS.map { |field| [I18n.t(field, scope: "admin.transaction_search.payment_type_fields"), field] }
            .select { |_label, value| value.in?(only) }
    end

    def payment_type_options
      self.class.payment_type_options
    end

    def options
      self.class.options
    end

    def multipart?
      true
    end

    def search(params)
      params ||= {}
      start_date = to_date(params[:start])
      end_date = to_date(params[:end])
      @date_range_field = extract_date_range_field(params)
      @payment_type_field = params[:payment_type_field] || "all"

      order_details
        .action_in_date_range(@date_range_field, start_date, end_date, @payment_type_field)
        .ordered_by_action_date(@date_range_field)
    end

    def to_date(param_value)
      parse_usa_date(param_value.to_s.tr("-", "/"))
    end

    def extract_date_range_field(params)
      field = params.try(:[], :field)
      FIELDS.include?(field.to_s) ? field.to_s : "fulfilled_at"
    end

    def label_name
      I18n.t("search_field.date_range")
    end

  end

end
