class Loan < ApplicationRecord
  belongs_to :item

  validates :borrower_name, presence: true
  validates :borrowed_at, presence: true
end
