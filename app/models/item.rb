class Item < ApplicationRecord
  has_many :loans, dependent: :destroy

  validates :name, :category, :condition, presence: true
  validates :available, inclusion: { in: [ true, false ] }
end
