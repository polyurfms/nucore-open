# frozen_string_literal: true

require "rails_helper"
require "account_builder_shared_examples"

RSpec.describe ChequeOrOtherAccountBuilder, type: :service do
  let(:options) do
    {
      account_params_key: "cheque_or_other_account",
      account_type: "ChequeOrOtherAccount",
      account_number: account_number ,
      current_user: user,
      q: facility,
      owner_user: user,
      params: params,
    }
  end
  let(:params) do
    ActionController::Parameters.new(
      credit_card_account: {
        name_on_card: "First Last",
        expiration_month: 1.year.from_now.month,
        expiration_year: 1.year.from_now.year,
        description: "Cheque/Other",

      },
    )
  end

  it_behaves_like "AccountBuilder#build"
end
