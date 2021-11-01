module ExternalAccounts

  class ResearchProjectMember < ApplicationRecord

    belongs_to :research_project, inverse_of: :research_project_members, required: true

    def to_s
      username
    end

  end

end
