module Loans
  class Borrow
    class NotAvailableError < StandardError; end

    def self.call(item_id:, borrower_name:, now: Time.current)
      Item.transaction do
        item = Item.lock.find(item_id)
        raise NotAvailableError, "Item is not available" unless item.available?

        loan = Loan.create!(
          item: item,
          borrower_name: borrower_name,
          borrowed_at: now
        )

        item.update!(available: false)
        loan
      end
    end
  end
end
