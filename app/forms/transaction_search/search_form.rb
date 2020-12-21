# frozen_string_literal: true

module TransactionSearch

  class SearchForm

    include ActiveModel::Model

    include DateHelper

    attr_accessor :date_range_field, :date_range_start, :date_range_end, :allowed_date_fields
    attr_accessor :facilities, :accounts, :products, :account_owners,
                  :order_statuses, :statements, :date_ranges, :ordered_fors

    def self.model_name
      ActiveModel::Name.new(self, nil, "Search")
    end

    def initialize(params, defaults: default_params)
      # If defaults are given, they are merged with the default_params (so we have
      # everything needed, even if the provided defaults are missing one of our
      # defaults.
      full_defaults = defaults.reverse_merge(default_params)
      # okay to use to_unsafe_h here because we are not persisting anything (just a search form)
      super(full_defaults.merge(params&.to_unsafe_h || {}))
    end

    def [](field)
      if field == :date_ranges
        date_params
      else
        public_send(field)
      end
    end

    def date_params
      start_d = parse_ddmmmyyyy_import_date(date_range_start)
      end_d = parse_ddmmmyyyy_import_date(date_range_end)

      {
        field: date_range_field,
        start: start_d,
        end: end_d,
      }
    end

    private

    def default_params
      {
        date_range_field: "fulfilled_at",
        allowed_date_fields: TransactionSearch::DateRangeSearcher::FIELDS,
      }
    end

  end

end
