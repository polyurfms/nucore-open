# frozen_string_literal: true

module ExternalAccounts

  module LinkCollectionExtension

    extend ActiveSupport::Concern

    included do
      def payment_sources
        NavTab::Link.new(
          tab: :payment_sources,
          text: t_my(Account),
          subnav: [accounts, transactions, transactions_in_review, payment_source_requests],
        )
      end
    
    end

    def payment_source_requests
      NavTab::Link.new(tab: :payment_source_requests, text: I18n.t("pages.payment_source_requests"), url: payment_source_requests_path)
    end

  end

end
