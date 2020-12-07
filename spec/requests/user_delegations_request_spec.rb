require 'rails_helper'

RSpec.describe "UserDelegations", type: :request do

  describe "GET /delete" do
    it "returns http success" do
      get "/user_delegations/delete"
      expect(response).to have_http_status(:success)
    end
  end

end
