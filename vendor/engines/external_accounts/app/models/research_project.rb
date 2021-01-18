module ExternalAccounts

  class ResearchProject < ApplicationRecord

    has_many :research_project_members, inverse_of: :research_project

    def to_s
      pgms_project_id
    end

  end

end
