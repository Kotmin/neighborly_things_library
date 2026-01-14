module Api
  class LoansController < ActionController::API
    rescue_from Loans::Borrow::NotAvailableError, with: :conflict

    def create
      loan = Loans::Borrow.call(
        item_id: params.require(:item_id),
        borrower_name: params.require(:borrower_name)
      )

      render json: loan.as_json(only: %i[id item_id borrower_name borrowed_at returned_at created_at updated_at]), status: :created
    end

    private

    def conflict(_e)
      render json: { error: "item_not_available" }, status: :conflict
    end
  end
end
