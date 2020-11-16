# frozen_string_literal: true

require "rails_helper"
require "account_builder_shared_examples"

RSpec.describe ChequeOrOtherAccountBuilder, type: :service do
  let(:options) do
    {
      account_params_key: "cheque_or_other_account",
      account_type: "ChequeOrOtherAccountBuilder",
      account_number: account_number ,
      current_user: user,
      facility: facility,
      owner_user: user,
      params: params,
    }
  end
  let(:params) do
    ActionController::Parameters.new(
      credit_card_account: {
        name_on_card: "First Last",
        description: "A Cheque/Other order",
        formatted_expires_at: I18n.l(1.year.from_now.to_date, format: :usa),
        description: "Cheque/Other"
      },
    )
  end

  it_behaves_like "AccountBuilder#build"
end
