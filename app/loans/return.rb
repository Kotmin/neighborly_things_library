module Loans
  class Return
    class NotBorrowedError < StandardError; end

    def self.call(item_id:, now: Time.current)
      Item.transaction do
        item = Item.lock.find(item_id)

        active_loan = item.loans.where(returned_at: nil).order(borrowed_at: :desc).first
        raise NotBorrowedError, "Item is not currently borrowed" if active_loan.nil?

        active_loan.update!(returned_at: now)
        item.update!(available: true)

        active_loan
      end
    end
  end
end
