# frozen_string_literal: true

class UserAgreement < ApplicationRecord
    belongs_to :facility
    belongs_to :user
end
