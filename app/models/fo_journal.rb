class FoJournal < ApplicationRecord
  belongs_to :order_detail, inverse_of: :fo_journal
end
